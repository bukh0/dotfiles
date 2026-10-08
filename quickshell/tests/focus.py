#!/usr/bin/env python3
"""Exercise real panel focus hierarchy with an isolated text field."""
from qt_tools import qmltestrunner
import os, pathlib, re, subprocess, tempfile
src=pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-focus-audit-') as d:
 p=pathlib.Path(d)
 s=(src/'components/ControlPanel.qml').read_text()
 s=re.sub(r'^import Quickshell.*\n','',s,flags=re.M).replace('PanelWindow {','Rectangle {',1)
 s=re.sub(r'    WlrLayershell.keyboardFocus:.*','',s)
 s=re.sub(r'    anchors \{.*?\n    \}','',s,count=1,flags=re.S)
 s=re.sub(r'    mask: Region \{.*?\n    \}','',s,count=1,flags=re.S)
 # Keep the real overlay/loader hierarchy; put a normal TextField exactly
 # where the Wi-Fi password form is loaded, with no network dependencies.
 start=s.index('    Component {\n        id: panelContent')
 s=s[:start]+'''    Component {
        id: panelContent
        TextField {
            objectName: "auditPassword"
            placeholderText: "Password"
            HoverHandler { blocking: true }
        }
    }
}
'''
 (p/'ControlPanel.qml').write_text(s)
 (p/'Colors.qml').write_bytes((src/'components/Colors.qml').read_bytes())
 theme=(src/'profiles/default/Theme.qml').read_text()
 theme='\n'.join(x for x in theme.splitlines() if x!='import Quickshell' and 'sysmonPath:' not in x)
 (p/'Theme.qml').write_text(theme)
 (p/'NetworkService.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property string awaitingPasswordFor: ""; function cancelPasswordPrompt() {} }')
 (p/'qmldir').write_text('singleton Colors 1.0 Colors.qml\nsingleton Theme 1.0 Theme.qml\nsingleton NetworkService 1.0 NetworkService.qml\n')
 (p/'tst_focus.qml').write_text('''import QtQuick
import QtQuick.Controls
import QtTest
Item {
 width: 800; height: 600
 ControlPanel { id: panel; width: 800; height: 600 }
 TestCase {
  name: "ControlPanelEscape"; when: windowShown
  function test_escapeFromPassword() {
   panel.isOpen = true; panel.pinned = true; wait(100)
   keyClick(Qt.Key_Escape); compare(panel.isOpen,false,"initial Escape closes")
   panel.isOpen = true; panel.pinned = true; wait(100)
   const field=findChild(panel,"auditPassword"); verify(field !== null)
   field.forceActiveFocus(); verify(field.activeFocus)
   keyClick(Qt.Key_Escape)
   compare(panel.isOpen,false,"Escape should close after focusing password field")
  }
  function test_hoverBridge() {
   mouseMove(panel, 2, 2)
   panel.beginHoverOpen()
   const bridge=findChild(panel,"controlPanelHoverBridge")
   verify(bridge !== null)
   compare(bridge.y,panel.barHeight,"hover region never overlaps the bar")
   wait(panel.slideDuration + 30)
   mouseMove(panel, panel.width / 2, panel.barHeight + 2)
   wait(30)
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen,"gap between clock and drawer keeps panel open")
   mouseMove(panel, panel.width / 2, panel.openY + 20)
   wait(30)
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen,"drawer content keeps panel open")
   mouseMove(panel, 2, 2)
   wait(panel.hoverCloseDelay + 40)
   verify(!panel.isOpen,"leaving both regions closes panel")
  }
  function test_returnToClock() {
   mouseMove(panel, 2, 2)
   panel.beginHoverOpen()
   panel.scheduleHoverClose()
   panel.triggerHovered = true
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen,"pending close cannot hide a hovered clock's panel")
   panel.triggerHovered = false
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(!panel.isOpen)
  }
 }
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=d)
 runner = qmltestrunner()
 r=subprocess.run([runner,'-input',str(p/'tst_focus.qml')],env=env,capture_output=True,text=True,timeout=8)
 print(r.stdout+r.stderr)
 assert r.returncode == 0, 'Control panel Escape regression failed'
