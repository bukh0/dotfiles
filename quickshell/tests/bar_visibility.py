"""Exercise the shell's actual bar bindings using two reactive monitor fixtures."""
from pathlib import Path
import os,re,subprocess,tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parent.parent
source=(ROOT/'components/shell.qml').read_text()
controls=source[source.index('    PersistentProperties {'):source.index('    // Profiles import')]
controls=re.sub(r'    PersistentProperties \{\n        id: notificationHistory.*?\n    \}\n', '', controls, flags=re.S)
controls=controls.replace('PersistentProperties {','QtObject {').replace('IpcHandler {','QtObject {\n        id: controls\n        property string target: ""').replace('        target: "bar"\n','').replace('Hyprland.','fakeHyprland.')
start=source.index('            Item {',source.index('    Variants {'))
output=source[start:source.index('\n        }\n    }\n}',start)].strip()
output=output.replace('Hyprland.','fakeHyprland.').replace('Bar {','Rectangle {\n                    property var screen\n                    objectName: "bar"')
with tempfile.TemporaryDirectory(prefix='qs-bar-visibility-') as directory:
 p=Path(directory)
 (p/'tst_bar.qml').write_text('''import QtQuick
import QtTest
Item {
 width: 800; height: 600
 QtObject { id: fakeHyprland; property int refreshes: 0
  function monitorFor(screen) { return screen }
  function refreshWorkspaces() { refreshes++ }
 }
'''+controls+'''
 component Output: '''+output+'''
 QtObject { id: firstWorkspace; property bool hasFullscreen: false }
 QtObject { id: otherWorkspace; property bool hasFullscreen: false }
 QtObject { id: secondWorkspace; property bool hasFullscreen: false }
 QtObject { id: first; property var activeWorkspace: firstWorkspace }
 QtObject { id: second; property var activeWorkspace: secondWorkspace }
 Output { id: a; modelData: first }
 Output { id: b; modelData: second }
 TestCase {
  name: "BarVisibility"; when: windowShown
  function bar(item) { return findChild(item,"bar") }
  function init() {
   first.activeWorkspace=firstWorkspace;second.activeWorkspace=secondWorkspace
   firstWorkspace.hasFullscreen=false;secondWorkspace.hasFullscreen=false
   otherWorkspace.hasFullscreen=false;controls.show()
  }
  function test_fullscreenDoesNotHideBar() {
   compare(bar(a).visible,true);compare(bar(b).visible,true)
   firstWorkspace.hasFullscreen=true
   compare(bar(a).visible,true);compare(bar(b).visible,true)
   firstWorkspace.hasFullscreen=false
   compare(bar(a).visible,true)
   firstWorkspace.hasFullscreen=true;first.activeWorkspace=null
   compare(bar(a).visible,true)
  }
  function test_workspaceSwitch() {
   firstWorkspace.hasFullscreen=true
   first.activeWorkspace=otherWorkspace
   compare(bar(a).visible,true)
   first.activeWorkspace=firstWorkspace
   compare(bar(a).visible,true)
  }
  function test_manualPreference() {
   controls.hide();firstWorkspace.hasFullscreen=true;firstWorkspace.hasFullscreen=false
   compare(bar(a).visible,false);compare(bar(b).visible,false)
   controls.show();compare(bar(a).visible,true);compare(bar(b).visible,true)
   controls.toggle();compare(bar(a).visible,false)
   controls.toggle();compare(bar(a).visible,true)
  }
  function test_staleCompatibilityCall() {
   controls.setFullscreen(true)
   compare(bar(a).visible,true);compare(bar(b).visible,true)
   firstWorkspace.hasFullscreen=true;controls.setFullscreen(false)
   compare(bar(a).visible,true);compare(bar(b).visible,true)
   firstWorkspace.hasFullscreen=false
   compare(bar(a).visible,true)
  }
 }
}
''')
 result=subprocess.run([qmltestrunner(),'-input',str(p/'tst_bar.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 print(result.stdout+result.stderr)
 assert result.returncode==0
