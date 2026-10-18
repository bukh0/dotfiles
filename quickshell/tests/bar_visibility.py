"""Exercise the shell's actual bar bindings using two reactive monitor fixtures."""
from pathlib import Path
import os,re,subprocess,tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parent.parent
source=(ROOT/'components/shell.qml').read_text()
controls=source[source.index('    PersistentProperties {'):source.index('    // Profiles import')]
controls=re.sub(r'    PersistentProperties \{\n        id: notificationHistory.*?\n    \}\n', '', controls, flags=re.S)
controls=controls.replace('PersistentProperties {','QtObject {').replace('IpcHandler {','QtObject {\n        id: controls\n        property string target: ""').replace('        target: "bar"\n','').replace('Hyprland.','fakeHyprland.').replace('NotificationDaemon.', 'notifications.')
start=source.index('            Item {',source.index('    Variants {'))
output=source[start:source.index('\n        }\n    }\n}',start)].strip()
output=output.replace('Hyprland.','fakeHyprland.').replace('Bar {','Rectangle {\n                    property var screen\n                    objectName: "bar"')
visibility = source[source.index('    function barVisibleOn('):source.index('    NotificationDrawer {')].replace('Hyprland.', 'fakeHyprland.')
with tempfile.TemporaryDirectory(prefix='qs-bar-visibility-') as directory:
 p=Path(directory)
 (p/'tst_bar.qml').write_text('''import QtQuick
import QtTest
Item {
 id: shell
 width: 800; height: 600
 QtObject { id: notifications; property bool isDrawerOpen: false }
 QtObject { id: fakeHyprland; property int refreshes: 0
  function monitorFor(screen) { return screen }
  function refreshWorkspaces() { refreshes++ }
  function refreshToplevels() {}
 }
'''+controls+visibility+'''
 component Output: '''+output+'''
 QtObject { id: client; property var lastIpcObject: ({fullscreen: 0, fullscreenClient: 0}) }
 QtObject { id: secondClient; property var lastIpcObject: ({fullscreen: 0}) }
 QtObject { id: firstWorkspace; property bool hasFullscreen: false; property var toplevels: ({values: [client]}) }
 QtObject { id: otherWorkspace; property bool hasFullscreen: false }
 QtObject { id: secondWorkspace; property bool hasFullscreen: false; property var toplevels: ({values: [secondClient]}) }
 QtObject { id: first; property var activeWorkspace: firstWorkspace }
 QtObject { id: second; property var activeWorkspace: secondWorkspace }
 Output { id: a; modelData: first }
 Output { id: b; modelData: second }
 TestCase {
  name: "BarVisibility"; when: windowShown
  function bar(item) { return findChild(item,"bar") }
  function init() {
   client.lastIpcObject = {fullscreen: 0}; secondClient.lastIpcObject = {fullscreen: 0}
   firstWorkspace.toplevels = {values: [client]}
   first.activeWorkspace=firstWorkspace;second.activeWorkspace=secondWorkspace
   firstWorkspace.hasFullscreen=false;secondWorkspace.hasFullscreen=false
   otherWorkspace.hasFullscreen=false;controls.show()
  }
  function test_maximizeVersusFullscreen() {
   compare(bar(a).visible,true);compare(bar(b).visible,true)
   firstWorkspace.hasFullscreen=true
   client.lastIpcObject = {fullscreen: 1, fullscreenClient: 1}
   compare(bar(a).visible,true,"Super+F maximizes without hiding bar")
   client.lastIpcObject = {fullscreen: 2, fullscreenClient: 2}
   compare(bar(a).visible,false,"Super+Shift+F hides only its monitor's bar")
   compare(bar(b).visible,true)
   client.lastIpcObject = {fullscreen: 0, fullscreenClient: 2}
   compare(bar(a).visible,true,"Client-requested fake fullscreen must not hide the bar")
   client.lastIpcObject = {fullscreen: 2}
   first.activeWorkspace=null
   compare(bar(a).visible,true)
  }
  function test_workspaceSwitchAndClose() {
   client.lastIpcObject = {fullscreen: 2}
   first.activeWorkspace=otherWorkspace
   compare(bar(a).visible,true)
   first.activeWorkspace=firstWorkspace
   compare(bar(a).visible,false)
   firstWorkspace.toplevels = {values: []}
   compare(bar(a).visible,true)
  }
  function test_notificationOffsets() {
   client.lastIpcObject = {fullscreen: 2}
   compare(shell.barVisibleOn(first),false)
   compare(shell.barVisibleOn(second),true)
   client.lastIpcObject = {fullscreen: 1}
   compare(shell.barVisibleOn(first),true)
   controls.hide()
   compare(shell.barVisibleOn(first),false)
   compare(shell.barVisibleOn(second),false)
  }
  function test_manualPreference() {
   notifications.isDrawerOpen=true
   controls.hide();compare(notifications.isDrawerOpen,false);firstWorkspace.hasFullscreen=true;firstWorkspace.hasFullscreen=false
   compare(bar(a).visible,false);compare(bar(b).visible,false)
   controls.show();compare(bar(a).visible,true);compare(bar(b).visible,true)
   notifications.isDrawerOpen=true
   controls.toggle();compare(notifications.isDrawerOpen,false);compare(bar(a).visible,false)
   controls.toggle();compare(bar(a).visible,true)
  }
  function test_staleCompatibilityCall() {
   controls.setFullscreen(true)
   compare(bar(a).visible,true);compare(bar(b).visible,true)
   client.lastIpcObject = {fullscreen: 2};controls.setFullscreen(false)
   compare(bar(a).visible,false);compare(bar(b).visible,true)
   client.lastIpcObject = {fullscreen: 0}
   compare(bar(a).visible,true)
  }
 }
}
''')
 result=subprocess.run([qmltestrunner(),'-input',str(p/'tst_bar.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 print(result.stdout+result.stderr)
 assert result.returncode==0
