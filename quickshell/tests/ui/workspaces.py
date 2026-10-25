"""Keep extra workspace buttons on their own monitor, using mock monitor objects."""
import os, shutil, subprocess, tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qs-workspaces-') as directory:
 p=Path(directory)
 shutil.copytree(root/'profiles/default',p/'profile')
 source=(root/'components/Workspaces.qml').read_text()
 source=source.replace('import Quickshell.Hyprland\n','')
 source=source.replace('readonly property var workspaceList: Hyprland.workspaces.values','property var workspaceList: []')
 source=source.replace('readonly property var monitor: Hyprland.monitorFor(root.screen)','property var monitor: null')
 source=source.replace('Hyprland.', 'root.hyprland.')
 source=source.replace('id: root', 'id: root\n    property var hyprland')
 (p/'profile/Workspaces.qml').write_text(source)
 (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "profile" as Profile
ShellRoot {
 QtObject {
  id: mockHyprland
  property bool usingLua: true
  property var calls: []
  function dispatch(value) { calls.push(value) }
 }
 property var first: ({name: "eDP-1", activeWorkspace: {id: 4}})
 property var second: ({activeWorkspace: {id: 8}})
 property var workspaces: [
  {id: 1, monitor:first, toplevels:{values:[{}]}},
  {id: 4, monitor:first, toplevels:{values:[]}},
  {id: 7, monitor:first, toplevels:{values:[{}]}},
  {id: 8, monitor:second, toplevels:{values:[]}},
  {id: 9, monitor:second, toplevels:{values:[{}]}}]
 Window {
  Profile.Workspaces { id: a; monitor:first; workspaceList:workspaces; hyprland:mockHyprland }
  Profile.Workspaces { id: b; monitor:second; workspaceList:workspaces; hyprland:mockHyprland }
 }
 Timer { interval: 200; running:true; onTriggered: {
  if (JSON.stringify(a.allIds) !== "[1,2,3,4,7]" || JSON.stringify(b.allIds) !== "[1,2,3,8,9]") console.error("FAIL",a.allIds,b.allIds)
  else {
   for (let lua of [true, false]) {
    mockHyprland.usingLua = lua
    mockHyprland.calls = []
    a.switchWorkspace(2)
    a.scrollWorkspace(true)
    a.scrollWorkspace(false)
    const actual = mockHyprland.calls
    const expected = lua ? [
      'hl.dsp.focus({ workspace = "2" })',
      'hl.dsp.focus({ monitor = "eDP-1" })',
      'hl.dsp.focus({ workspace = "e-1" })',
      'hl.dsp.focus({ monitor = "eDP-1" })',
      'hl.dsp.focus({ workspace = "e+1" })'
    ] : ['workspace 2', 'focusmonitor eDP-1', 'workspace e-1', 'focusmonitor eDP-1', 'workspace e+1']
    if (JSON.stringify(actual) !== JSON.stringify(expected)) console.error("FAIL dispatch", actual)
   }
   console.log("WORKSPACES PASS")
  }
  Qt.quit()
 } }
}
''')
 r=subprocess.run(['quickshell','-p',str(p/'shell.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 output=r.stdout+r.stderr
 print(output)
 assert 'WORKSPACES PASS' in output and 'FAIL' not in output
