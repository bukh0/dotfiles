"""Clipboard padding consumes clicks; delayed monitor discovery selects once."""
import os
from pathlib import Path
import subprocess
import tempfile

from harness import stub_colors
from qt_tools import qmltestrunner

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'shell.qml').read_text()
start = source.index('        id: window') + len('        id: window')
end = source.index('        anchors {', start)
logic = source[start:end].replace('Hyprland.', 'monitors.').replace('target: Hyprland', 'target: monitors')
logic = logic.replace('Quickshell.', 'outputs.').replace('target: Quickshell', 'target: outputs')
with tempfile.TemporaryDirectory(prefix='clipboard-interactions-') as directory:
    stage = Path(directory)
    (stage / 'ClipboardView.qml').write_text((ROOT / 'ClipboardView.qml').read_text())
    stub_colors(stage / 'Colors.qml')
    (stage / 'qmldir').write_text('singleton Colors 1.0 Colors.qml\n')
    (stage / 'tst_interactions.qml').write_text('''import QtQuick
import QtTest
Item {
 width: 1000; height: 750
 property int outsideClicks: 0
 MouseArea { anchors.fill: parent; onClicked: parent.outsideClicks++ }
 QtObject {
  id: service
  property var entries: []
  property var preview: ({})
  property bool loading: false
  property bool previewLoading: false
  property bool busy: false
  property string error: ""
  function inspect(id) {}
  function refresh() {}
 }
 ClipboardView { id: view; x: 30; y: 30; width: 940; height: 650; service: service }
 QtObject { id: first; property string name: "first" }
 QtObject { id: second; property string name: "second" }
 QtObject { id: monitors; property var focusedMonitor: null; function refreshMonitors() {} }
 QtObject { id: outputs; property var screens: [first, second] }
 Item { id: window; property var screen
''' + logic + '''
 }
 TestCase {
  name: "ClipboardInteractions"; when: windowShown
  function test_panelPaddingDoesNotDismiss() {
   outsideClicks = 0
   mouseClick(view, 10, 10)
   compare(outsideClicks, 0, "panel padding passed click to outside dismissal")
   mouseClick(view, 35, 36)
   compare(outsideClicks, 0, "panel heading passed click to outside dismissal")
   mouseClick(parent, 5, 5)
   compare(outsideClicks, 1)
   const search = findChild(view, "clipboardSearch")
   mouseClick(search, 20, 20)
   keyClick(Qt.Key_A)
   compare(search.text, "a", "panel shield blocked search input")
  }
  function test_lateFocusedMonitor() {
   compare(window.screen, first)
   monitors.focusedMonitor = second
   compare(window.screen, second, "clipboard stayed on fallback monitor")
   monitors.focusedMonitor = first
   compare(window.screen, second, "open clipboard followed subsequent focus")
  }
 }
}
''')
    result = subprocess.run([qmltestrunner(), '-input', str(stage)],
                            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory),
                            capture_output=True, text=True, timeout=15)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
