"""Real wheel events with mocked music/compositor backends and Bluetooth reports."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
from qt_tools import qmltestrunner
from harness import stub_colors

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-input-edges-') as directory:
    p = Path(directory)
    for name in ('MusicWidget.qml', 'Workspaces.qml', 'Colors.qml'):
        source = (ROOT / 'components' / name).read_text()
        source = re.sub(r'^import Quickshell.*\n', '', source, flags=re.M)
        (p / name).write_text(source)
    stub_colors(p / "Colors.qml")
    (p / "BaseTheme.qml").write_text((ROOT / "components/BaseTheme.qml").read_text().replace("import Quickshell\n", ""))
    (p / 'Theme.qml').write_text((ROOT / 'profiles/default/Theme.qml').read_text()
        .replace('import Quickshell\n', '').replace('Quickshell.shellPath("../../native/sysmon")', '""'))
    (p / 'MusicService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property ListModel model: ListModel {}
 property string selectedPlayer: "1"
 readonly property int selectedIndex: Number(selectedPlayer)
 function findPlayer(name) { return null }
}
''')
    (p / 'Hyprland.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property var workspaces: ({values: []})
 property bool usingLua: true
 property var calls: []
 function monitorFor(screen) { return {name: "Test", activeWorkspace: {id: 1}} }
 function dispatch(command) { calls = calls.concat([command]) }
}
''')
    report = (ROOT / 'components/BluetoothService.qml').read_text()
    match = re.search(r"(?m)^(?P<indent>[ \t]*)function _reportResult\s*\(.*?^(?P=indent)\}", report, re.S)
    assert match, "Could not locate _reportResult function"
    report = match.group(0)
    (p / 'BluetoothReport.qml').write_text('import QtQuick\nItem {\n id: root\n property var notices: []\n function notify(title, text) { notices = notices.concat([text]) }\n' + report + '\n}')
    (p / 'qmldir').write_text(''.join(f'singleton {name} 1.0 {name}.qml\n' for name in ('Theme', 'Colors', 'MusicService', 'Hyprland')))
    (p / 'tst_input.qml').write_text('''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest
import "." as Config
Item {
 width: 700; height: 500
 Config.Workspaces { id: workspaces; x: 10; y: 10 }
 ScrollView {
  id: scroll; x: 10; y: 70; width: 450; height: 180
  contentWidth: availableWidth
  contentHeight: content.implicitHeight
  ColumnLayout {
   id: content; width: scroll.availableWidth
   Config.MusicWidget { id: music; preferVerticalScroll: false }
   Item { Layout.fillWidth: true; implicitHeight: 650 }
  }
 }
 Config.BluetoothReport { id: report }
 TestCase {
  name: "InputEdges"; when: windowShown
  function init() {
   Config.MusicService.model.clear()
   for (let i = 0; i < 3; i++) Config.MusicService.model.append({player: String(i), playerName: "Player " + i,
    title: "Track", artist: "", album: "", status: "Paused", artUrl: ""})
   Config.MusicService.selectedPlayer = "1"
   Config.Hyprland.calls = []
   Config.Hyprland.workspaces = {values: []}
   Config.Hyprland.usingLua = true
   music.preferVerticalScroll = false
   scroll.contentItem.cancelFlick()
   scroll.contentItem.contentY = 0
   report.notices = []
   wait(250)
  }
  function test_existingWorkspaceClick() {
   Config.Hyprland.workspaces = {values: [{id: 1, activate: function() { fail("bypassed dispatcher") }}]}
   for (const lua of [true, false]) {
    Config.Hyprland.usingLua = lua
    Config.Hyprland.calls = []
    mouseClick(workspaces, 10, 10)
    compare(Config.Hyprland.calls.length, 2)
    verify(Config.Hyprland.calls[0].includes(lua ? 'monitor = "Test"' : 'focusmonitor Test'))
    compare(Config.Hyprland.calls[1], lua ? 'hl.dsp.focus({ workspace = "1" })' : 'workspace 1')
   }
  }
  function test_workspaceIdle() {
   mouseWheel(workspaces, 10, 10, 0, -60)
   wait(200)
   mouseWheel(workspaces, 10, 10, 0, -60)
   compare(Config.Hyprland.calls.length,0,"Separate gestures must not combine")
   mouseWheel(workspaces, 10, 10, 0, -60)
   compare(Config.Hyprland.calls.length,2)
  }
  function test_workspaceLargeDelta() {
   mouseWheel(workspaces, 10, 10, 0, -240)
   compare(Config.Hyprland.calls.length,4,"Two notches must switch twice")
   Config.Hyprland.calls=[]
   mouseWheel(workspaces, 10, 10, 0, 1200)
   compare(Config.Hyprland.calls.length,6,"Cap large bursts at three switches")
   Config.Hyprland.calls=[]
   mouseWheel(workspaces, 10, 10, 0, -120)
   compare(Config.Hyprland.calls.length,2,"Discard capped excess rather than carrying a backlog")
   verify(Config.Hyprland.calls[1].includes("e+1"))
  }
  function test_workspaceReverse() {
   mouseWheel(workspaces, 10, 10, 0, -60)
   mouseWheel(workspaces, 10, 10, 0, 60)
   mouseWheel(workspaces, 10, 10, 0, 60)
   compare(Config.Hyprland.calls.length,2,"Reversal must start fresh")
   verify(Config.Hyprland.calls[1].includes("e-1"))
  }
  function test_musicIdle() {
   mouseWheel(music, 100, 20, 0, -60)
   wait(200)
   mouseWheel(music, 100, 20, 0, -60)
   compare(Config.MusicService.selectedIndex,1,"Separate music gestures must not combine")
   mouseWheel(music, 100, 20, 0, -60)
   compare(Config.MusicService.selectedIndex,2)
  }
  function test_musicReverse() {
   mouseWheel(music, 100, 20, 0, -60)
   mouseWheel(music, 100, 20, 0, 60)
   mouseWheel(music, 100, 20, 0, 60)
   compare(Config.MusicService.selectedIndex,0)
  }
  function test_panelScroll() {
   music.preferVerticalScroll = true
   mouseWheel(music, 100, 20, 0, -120)
   wait(150)
   verify(scroll.contentItem.contentY > 0,"Vertical wheel must reach the parent ScrollView")
   compare(Config.MusicService.selectedIndex,1)
   scroll.contentItem.cancelFlick()
   scroll.contentItem.contentY = 0
   wait(100)
   mouseWheel(music, 100, 20, -120, 0)
   compare(Config.MusicService.selectedIndex,2,"Horizontal wheel must still switch players")
  }
  function test_singlePlayerScroll() {
   Config.MusicService.model.remove(1,2)
   Config.MusicService.selectedPlayer = "0"
   wait(50)
   mouseWheel(music, 100, 20, 0, -120)
   wait(150)
   verify(scroll.contentItem.contentY > 0,"A single player must not consume scrolling")
  }
  function test_bluetoothNamesAndFailures() {
   for (const name of ["Error Buds", "Fail-Safe", "Already Connected"])
    report._reportResult(0,"[CHG] Device AA:BB:CC:DD:EE:FF Name: " + name + "\\nConnection successful", "connect")
   compare(report.notices.length,0)
   report._reportResult(0,"Failed to connect: org.bluez.Error.Failed", "connect")
   compare(report.notices.length,1)
   report._reportResult(0,"Failed to connect: org.bluez.Error.AlreadyConnected", "connect")
   compare(report.notices.length,1)
   report._reportResult(1,"[CHG] Device AA:BB:CC:DD:EE:FF Name: Already Connected\\nFailed to connect: org.bluez.Error.Failed", "connect")
   compare(report.notices.length,2,"Device names must not hide real failures either")
   report._reportResult(124,"", "connect")
   compare(report.notices.length,3)
  }
 }
}
''')
    result = subprocess.run([qmltestrunner(), '-input', str(p / 'tst_input.qml')],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory), capture_output=True, text=True, timeout=15)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
