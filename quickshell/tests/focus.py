#!/usr/bin/env python3
"""Exercise real panel focus hierarchy with isolated text, mouse and music controls."""
from qt_tools import qmltestrunner
from harness import stub_colors
import os, pathlib, re, subprocess, tempfile
src=pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-focus-audit-') as d:
 p=pathlib.Path(d)
 (p/'art#100% ?.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>')
 s=(src/'components/ControlPanel.qml').read_text()
 s=re.sub(r'^import Quickshell.*\n','',s,flags=re.M).replace('PanelWindow {','Rectangle {',1)
 s=re.sub(r'    exclusionMode:.*\n', '', s)
 s=re.sub(r'    WlrLayershell.layer:.*\n', '', s)
 s=re.sub(r'    WlrLayershell.keyboardFocus:.*\n', '', s)
 s=re.sub(r'    anchors \{.*?\n    \}','',s,count=1,flags=re.S)
 s=s.replace('id: panelHover', 'id: panelHover; objectName: "auditPanelHover"')
 s=s.replace('mask: Region {', 'property QtObject inputRegion: QtObject {')
 s=re.sub(r'^(        )(x|y|width|height):', r'\1property real \2:', s, count=4, flags=re.M)
 # Keep the real overlay/loader hierarchy with cooperative hover controls
 # and actual MusicWidget buttons, without network or media side effects.
 start=s.index('    Component {\n        id: panelContent')
 s=s[:start]+'''    Component {
        id: panelContent
        ColumnLayout {
            TextField {
                objectName: "auditPassword"
                Layout.fillWidth: true
                placeholderText: "Password"
                property alias controlHovered: childHover.hovered
                HoverHandler { id: childHover; blocking: false }
            }
            MouseArea {
                objectName: "auditMouseArea"
                Layout.fillWidth: true
                implicitHeight: 30
                hoverEnabled: true
            }
            SliderRow {
                objectName: "auditSlider"
                property bool dragging: isDragging
                onDragged: val => value = val
            }
            MusicWidget {}
        }
    }
}
'''
 (p/'ControlPanel.qml').write_text(s)
 stub_colors(p / "Colors.qml")
 theme=(src/'profiles/default/Theme.qml').read_text()
 theme='\n'.join(x for x in theme.splitlines() if x!='import Quickshell' and 'sysmonPath:' not in x)
 (p / "BaseTheme.qml").write_text((src / "components/BaseTheme.qml").read_text().replace("import Quickshell\n", ""))
 (p/'Theme.qml').write_text(theme)
 (p/'NetworkService.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property string actionKind: ""; property bool submittingPassword: false; property string submittingPasswordScreen: ""; property string awaitingPasswordFor: ""; property string awaitingPasswordScreen: ""; function cancelPasswordPrompt(screenName) { if (screenName === undefined || (awaitingPasswordFor !== "" && screenName === awaitingPasswordScreen) || (submittingPassword && screenName === submittingPasswordScreen)) { awaitingPasswordFor = ""; submittingPassword = false; submittingPasswordScreen = "" } } }')
 for name in ('MusicWidget.qml', 'SliderRow.qml'):
  source = (src/'components'/name).read_text()
  source = re.sub(r'^import Quickshell.*\n', '', source, flags=re.M)
  if name == 'MusicWidget.qml':
   source = source.replace('id: pager', 'id: pager; objectName: "auditPager"', 1)
   source = source.replace('id: artImage', 'id: artImage; objectName: "auditArtwork"', 1)
  (p/name).write_text(source)
 (p/'MusicService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property ListModel model: ListModel {
  ListElement { player: "test"; playerName: "Test"; title: "Track"; artist: ""; album: ""; status: "Playing"; artUrl: "" }
 }
 property int selectedIndex: 0
 property string selectedPlayer: "test"
 property var calls: []
 property QtObject backend: QtObject {
  property bool canGoPrevious: true
  property bool canTogglePlaying: true
  property bool canGoNext: true
  function previous() { calls = calls.concat(["Previous track"]) }
  function togglePlaying() { calls = calls.concat(["Pause"]) }
  function next() { calls = calls.concat(["Next track"]) }
 }
 function findPlayer(name) { return backend }
}
''')
 (p/'qmldir').write_text('singleton Colors 1.0 Colors.qml\nBaseTheme 1.0 BaseTheme.qml\nsingleton Theme 1.0 Theme.qml\nsingleton NetworkService 1.0 NetworkService.qml\nsingleton MusicService 1.0 MusicService.qml\n')
 (p/'tst_focus.qml').write_text('''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest
Item {
 width: 800; height: 600
 ControlPanel { id: panel; width: 800; height: 600 }
 ControlPanel { id: otherPanel; width: 800; height: 600; outputName: "other"; x: 1000 }
 TestCase {
  name: "ControlPanelEscape"; when: windowShown
  function init() {
   otherPanel.isOpen = false
   panel.clockTriggerBottom = panel.barHeight
   panel.clockTriggerWidth = 192
   NetworkService.actionKind = ""
   NetworkService.submittingPassword = false
   NetworkService.submittingPasswordScreen = ""
   NetworkService.awaitingPasswordScreen = ""
   panel.triggerHovered = false
   panel.isOpen = false
   NetworkService.awaitingPasswordFor = ""
   mouseMove(panel, 2, 2)
   wait(panel.slideDuration + 30)
  }
  function test_musicArtworkPath() {
   panel.beginHoverOpen()
   wait(50)
   const art = findChild(panel, "auditArtwork")
   verify(art !== null)
   const old = MusicService.model.get(0).artUrl
   try {
    MusicService.model.setProperty(0, "artUrl", "ARTWORK_PATH")
    tryCompare(art, "status", Image.Ready)
    MusicService.model.setProperty(0, "artUrl", "ARTWORK_URL")
    tryCompare(art, "status", Image.Ready)
   } finally { MusicService.model.setProperty(0, "artUrl", old) }
  }
  function test_musicIndexDuringRemoval() {
   panel.beginHoverOpen()
   wait(50)
   const pager = findChild(panel, "auditPager")
   MusicService.model.append({player: "second", playerName: "Second", title: "", artist: "", album: "", status: "Paused", artUrl: ""})
   MusicService.selectedIndex = 1
   compare(pager.currentIndex, 1)
   MusicService.model.remove(1)
   compare(pager.currentIndex, 0, "stale selected index must not point beyond remaining pages")
   const saved = Object.assign({}, MusicService.model.get(0))
   MusicService.model.clear()
   compare(pager.currentIndex, 0, "empty model must not produce a negative index")
   MusicService.model.append(saved)
   MusicService.selectedIndex = 0
  }
  function test_savedConnectionStaysHoverOnly() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const focusBefore = panel.Window.window.activeFocusItem
   NetworkService.actionKind = "connect"
   verify(!panel.heldByUser)
   verify(!panel.inputRegion.full, "saved-network connection must not expand the mask")
   wait(30)
   compare(panel.Window.window.activeFocusItem, focusBefore, "saved connection must not take keyboard focus")
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 50)
   verify(!panel.isOpen, "ordinary connection must not hold hover panel open")
  }
  function test_connectionHoldAndRetry() {
   panel.beginHoverOpen()
   otherPanel.beginHoverOpen()
   NetworkService.awaitingPasswordFor = "test"
   NetworkService.submittingPasswordScreen = ""
   NetworkService.actionKind = "connect"
   NetworkService.submittingPassword = true
   NetworkService.awaitingPasswordFor = ""
   verify(!panel.hasPasswordPrompt)
   verify(panel.heldByUser)
   verify(!otherPanel.heldByUser)
   panel.scheduleHoverClose()
   otherPanel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 50)
   verify(panel.isOpen, "authentication holds owning panel")
   verify(!otherPanel.isOpen, "other output closes normally")
   NetworkService.awaitingPasswordFor = "test"
   NetworkService.submittingPassword = false
   NetworkService.actionKind = ""
   wait(panel.hoverCloseDelay + 50)
   verify(panel.isOpen, "failed authentication hands hold to retry prompt")
   NetworkService.awaitingPasswordFor = ""
   wait(panel.hoverCloseDelay + 50)
   verify(!panel.isOpen, "cleared hold resumes close")
  }
  function test_connectionCanBeDismissed() {
   NetworkService.submittingPasswordScreen = ""
   NetworkService.actionKind = "connect"
   NetworkService.submittingPassword = true
   panel.beginHoverOpen()
   panel.isOpen = false
   wait(panel.hoverCloseDelay + 50)
   verify(!panel.isOpen, "connection must not reopen explicitly dismissed panel")
   verify(!NetworkService.submittingPassword, "dismissal releases the submission hold")
  }
  function test_passwordBelongsToOneOutput() {
   panel.beginHoverOpen()
   otherPanel.beginHoverOpen()
   NetworkService.awaitingPasswordScreen = ""
   NetworkService.awaitingPasswordFor = "test"
   verify(panel.heldByUser)
   verify(!otherPanel.heldByUser, "other monitor must retain hover-only input")
   otherPanel.isOpen = false
   compare(NetworkService.awaitingPasswordFor, "test", "closing another monitor must not cancel this prompt")
   panel.isOpen = false
   compare(NetworkService.awaitingPasswordFor, "")
  }
  function test_largeFloatingMarginSeam() {
   panel.clockTriggerBottom = panel.barHeight - 8
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const guard = findChild(panel, "controlPanelHoverGuard")
   verify(guard.y < panel.clockTriggerBottom, "seam follows clock hit area with larger margins")
   mouseMove(panel, panel.width / 2, panel.clockTriggerBottom - 0.5)
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen)
  }
  function test_hoverOnlyEscapeInactive() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   keyClick(Qt.Key_Escape)
   verify(panel.isOpen, "hover-only panel must not register an active Escape shortcut")
  }
  function test_dragPastEdge() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const slider = findChild(panel, "auditSlider")
   mouseMove(slider, slider.width / 2, slider.height / 2)
   wait(30)
   mousePress(slider, slider.width / 2, slider.height / 2)
   verify(slider.isDragging)
   mouseMove(panel, 2, panel.height - 2)
   wait(panel.hoverCloseDelay + 50)
   verify(panel.isOpen, "dragging outside the card must not close the panel")
   mouseRelease(panel, 2, panel.height - 2)
   wait(30)
   mouseMove(panel, 3, panel.height - 2)
   wait(panel.hoverCloseDelay + 50)
   verify(!panel.isOpen, "release outside starts normal close grace")
  }
  function test_stripOutsideClockDoesNotPin() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const guard = findChild(panel, "controlPanelHoverGuard")
   mouseClick(panel, guard.x + 3, guard.y + 1)
   verify(!panel.pinned, "click outside the clock must not pin the panel")
  }
  function test_directEntryOverChild() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const field = findChild(panel, "auditPassword")
   mouseMove(field, field.width / 2, field.height / 2)
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen, "entering directly over a cooperative child keeps the panel open")
  }
  function test_childHoverAppearance() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const field = findChild(panel, "auditPassword")
   mouseMove(field, field.width / 2, field.height / 2)
   wait(30)
   verify(field.controlHovered, "child control hover feedback must remain available")
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen, "observing child hover must also keep the panel open")
  }
  function findControl(item, label) {
   if (item.label === label) return item
   for (let child of item.children) {
    const found = findControl(child, label)
    if (found) return found
   }
   return null
  }
  function test_musicHoverAndClicks() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   MusicService.calls = []
   for (let label of ["Previous track", "Pause", "Next track"]) {
    const button = findControl(panel, label)
    verify(button !== null, label)
    mouseMove(panel, 2, 2)
    wait(130)
    compare(button.color.a, 0, "background clears after leaving")
    mouseMove(button, button.width / 2, button.height / 2)
    wait(130)
    verify(button.color.a > 0.1, "playback button regains colored hover background")
    panel.scheduleHoverClose()
    wait(panel.hoverCloseDelay + 40)
    verify(panel.isOpen, "direct entry onto playback controls keeps panel open")
    mouseClick(button, button.width / 2, button.height / 2)
    compare(MusicService.calls[MusicService.calls.length - 1], label)
   }
   compare(MusicService.calls.length, 3, "each button invokes exactly one action")
  }
  function test_mouseAreaHover() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const area = findChild(panel, "auditMouseArea")
   mouseMove(area, area.width / 2, area.height / 2)
   verify(area.containsMouse)
   panel.scheduleHoverClose()
   wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen, "MouseArea controls keep ancestor hover active")
  }
  function test_cancelPromptAfterLeaving() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   mouseMove(panel, panel.width / 2, panel.barHeight + 2)
   NetworkService.awaitingPasswordFor = "test"
   mouseMove(panel, 2, 2)
   wait(40)
   NetworkService.cancelPasswordPrompt()
   wait(panel.hoverCloseDelay + 40)
   verify(!panel.isOpen, "ending the password hold schedules close without another pointer event")
  }
  function test_pinDoesNotStealFieldFocus() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const field = findChild(panel, "auditPassword")
   panel.pinned = true
   field.forceActiveFocus()
   wait(40)
   verify(field.activeFocus, "deferred background focus must preserve focused controls")
  }
  function test_clickOverlapPins() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const guard = findChild(panel, "controlPanelHoverGuard")
   mouseClick(panel, panel.width / 2, guard.y + 1)
   verify(panel.pinned, "clicking the overlap at the clock's lower edge should pin, not disappear")
   verify(panel.isOpen)
  }
  function test_maskMatchesGuard() {
   panel.beginHoverOpen()
   wait(panel.slideDuration + 30)
   const guard = findChild(panel, "controlPanelHoverGuard")
   compare(panel.inputRegion.x, guard.x)
   compare(panel.inputRegion.y, guard.y)
   compare(panel.inputRegion.width, guard.width)
   compare(panel.inputRegion.height, guard.height)
  }
  function test_escapeFromPassword() {
   panel.isOpen = true; panel.pinned = true; wait(100)
   keyClick(Qt.Key_Escape); compare(panel.isOpen,false,"initial Escape closes")
   panel.isOpen = true; panel.pinned = true; wait(100)
   const field=findChild(panel,"auditPassword"); verify(field !== null)
   mouseClick(field, field.width / 2, field.height / 2)
   verify(field.activeFocus, "hover observer must not intercept control clicks")
   keyClick(Qt.Key_Escape)
   compare(panel.isOpen,false,"Escape should close after focusing password field")
  }
  function test_hoverBridge() {
   mouseMove(panel, 2, 2)
   panel.beginHoverOpen()
   const bridge=findChild(panel,"controlPanelHoverBridge")
   verify(bridge !== null)
   compare(bridge.y,2,"input area begins at the top of its hover guard")
   compare(panel.hoverCloseDelay,510,"hover close delay")
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
  function test_nearBothEdges() {
   panel.isOpen = true; panel.pinned = false; wait(panel.slideDuration + 30)
   const guard=findChild(panel,"controlPanelHoverGuard")
   verify(guard !== null)
   mouseMove(panel, guard.x + 5, panel.barHeight + 30)
   wait(30); panel.scheduleHoverClose(); wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen,"Moving just outside the left edge must not flash the panel closed")
   mouseMove(panel, guard.x + guard.width - 5, panel.barHeight + 30)
   wait(30); panel.scheduleHoverClose(); wait(panel.hoverCloseDelay + 40)
   verify(panel.isOpen,"Moving just outside the right edge must not flash the panel closed")
   mouseMove(panel, 2, 2)
   wait(panel.hoverCloseDelay + 40)
   verify(!panel.isOpen,"The edge margin must not keep the panel open after leaving")
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
 test_path = p/'tst_focus.qml'
 test_path.write_text(test_path.read_text().replace('ARTWORK_PATH', str(p/'art#100% ?.svg')).replace('ARTWORK_URL', (p/'art#100% ?.svg').as_uri()))
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=d)
 runner = qmltestrunner()
 r=subprocess.run([runner,'-input',str(p/'tst_focus.qml')],env=env,capture_output=True,text=True,timeout=40)
 print(r.stdout+r.stderr)
 assert r.returncode == 0, 'Control panel Escape regression failed'
