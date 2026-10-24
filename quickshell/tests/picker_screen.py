"""Late compositor discovery selects the launch output once, without following focus."""
import os
from pathlib import Path
import subprocess
import tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parent.parent
source=(ROOT/'picker/shell.qml').read_text()
start=source.index('        property bool screenChosen:')
end=source.index('        // No anchors:',start)
logic=source[start:end].replace('Hyprland.','monitors.').replace('target: Hyprland','target: monitors').replace('Quickshell.','outputs.').replace('target: Quickshell','target: outputs')
with tempfile.TemporaryDirectory(prefix='qs-picker-screen-') as directory:
 p=Path(directory)
 (p/'tst_screen.qml').write_text('''import QtQuick
import QtTest
Item {
 QtObject { id: first; property string name: "first" }
 QtObject { id: second; property string name: "second" }
 QtObject { id: monitors; property var focusedMonitor: null; property int requests: 0; function refreshMonitors() { requests++ } }
 QtObject { id: outputs; property var screens: [first, second] }
 Item { id: window; property var screen
'''+logic+'''
 }
 TestCase { name:"PickerInitialScreen"; when:windowShown
  function test_lateFocus() {
   compare(window.screen,first); verify(!window.screenChosen); compare(monitors.requests,1)
   monitors.focusedMonitor=second
   compare(window.screen,second); verify(window.screenChosen)
   monitors.focusedMonitor=first
   compare(window.screen,second,"open picker must not follow later focus")
  }
 }
}
''')
 r=subprocess.run([qmltestrunner(),'-input',str(p)],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 assert r.returncode==0,r.stdout+r.stderr
 print('PASS late focused-monitor discovery without subsequent screen jumps')
