"""Check drawer geometry after wrapping, insertion, and notification updates."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
from qt_tools import qmltestrunner
from harness import stub_colors

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-notification-layout-') as directory:
    p = Path(directory)
    profile = p / 'profile'
    profile.mkdir()
    for name in ('NotificationDrawer.qml', 'NotificationButton.qml', 'NotificationActions.qml', 'Colors.qml', 'NotificationBody.js'):
        source = (ROOT / "components" / name.replace("NotificationPopup.qml", "NotificationPopupContent.qml").replace("NotificationDrawer.qml", "NotificationDrawerContent.qml")).read_text()
        (profile / name).write_text(source)
    stub_colors(profile / "Colors.qml")
    (profile / "BaseTheme.qml").write_text((ROOT / "components/BaseTheme.qml").read_text().replace("import Quickshell\n", ""))
    (profile / 'Theme.qml').write_text((ROOT / 'profiles' / os.environ.get('QS_TEST_PROFILE', 'default') / 'Theme.qml').read_text()
        .replace('import Quickshell\n', '').replace('Quickshell.shellPath("../../native/sysmon")', '""'))
    (profile / 'NotificationDaemon.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property ListModel notificationModel: ListModel {}
 property bool isDrawerOpen: true
 property bool drawerHovered: false
 property bool drawerPinned: true
 property bool doNotDisturb: false
 property var surfaceScreen: null
 property var actions: ({})
 function actionsFor(id) { return actions[id] || [] }
 function invokeAction(id, index) {}
 function cancelHoverClose() {}
 function scheduleHoverClose() {}
 function toggleDnd() { doNotDisturb = !doNotDisturb }
 function clearAll() { notificationModel.clear() }
 function closeNotificationById(id) {}
}
''')
    (profile / 'qmldir').write_text('BaseTheme 1.0 BaseTheme.qml\nsingleton Theme 1.0 Theme.qml\nsingleton Colors 1.0 Colors.qml\nsingleton NotificationDaemon 1.0 NotificationDaemon.qml\n')
    (p / 'tst_layout.qml').write_text('''import QtQuick
import QtTest
import "profile" as Config
Item {
 width: 1000; height: 800
 Config.NotificationDrawer { id: drawer; width: parent.width; height: parent.height }
 TestCase {
  name: "NotificationLayout"; when: windowShown
  property string longBody: "Here's a set mirroring the structure and difficulty of yours (modular exponentiation, finding moduli, proofs, counterexamples, a squares-mod-n proof)."
  function descendants(item) {
   let result = []
   for (const child of item.children || []) result = result.concat([child], descendants(child))
   return result
  }
  function list() { return descendants(drawer).find(item => typeof item.itemAtIndex === "function") }
  function row(id, body) {
   return {notifId: id, appName: "Firefox", summary: "Claude responded", body: body || "Short body",
    timeText: "", timestamp: Date.now(), urgency: 1, iconSource: ""}
  }
  function init() {
   Config.NotificationDaemon.notificationModel.clear()
   Config.NotificationDaemon.actions = ({})
   drawer.width = 1000
   Config.NotificationDaemon.isDrawerOpen = true
   wait(300)
  }
  function test_bodyLinksAreNotInertAnchors() {
   Config.NotificationDaemon.notificationModel.append(row(404, '<b>Message</b> <img alt="a > b" src="https://example.invalid/image"> <a title="a > b" href="https://example.invalid">Details</a>'))
   wait(300)
   const body = descendants(drawer).find(item => typeof item.text === "string" && item.text.includes("Details"))
   verify(!!body)
   compare(body.text, '<b>Message</b>  <a href="https://example.invalid">Details</a>')
  }
  function verifyGeometry() {
   const view = list()
   verify(!!view)
   for (let i = 0; i < view.count; i++) {
    const card = view.itemAtIndex(i)
    if (!card) continue
    const next = view.itemAtIndex(i + 1)
    if (next) verify(next.y >= card.y + card.height + view.spacing - 1,
     "Overlap at " + i + ": bottom=" + (card.y + card.height) + " next=" + next.y)
    for (const child of descendants(card)) {
     if (!child.visible || typeof child.notificationId !== "number") continue
     const bottom = child.mapToItem(card, 0, child.height).y
     verify(bottom <= card.height - 11, "Actions extend beyond card: " + bottom + " height=" + card.height)
    }
   }
  }
  function test_insertAndResize() {
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 4; i++) model.append(row(i))
   wait(350)
   model.insert(0, row(10, longBody))
   wait(40)
   Config.NotificationDaemon.actions = ({10: [{text: "Activate"}]})
   wait(350)
   verifyGeometry()
   drawer.width = 320
   wait(350)
   verifyGeometry()
   model.setProperty(1, "body", longBody)
   wait(350)
   verifyGeometry()
   model.remove(0)
   wait(350)
   verifyGeometry()
  }
  function test_expandMessage() {
   const model = Config.NotificationDaemon.notificationModel
   model.append(row(60, longBody.repeat(8)))
   model.append(row(61))
   wait(350)
   const card = list().itemAtIndex(0)
   const button = descendants(card).find(item => item.text === "Show more" && typeof item.click === "function")
   verify(!!button && button.visible, "Truncated messages need a way to read the rest")
   const collapsedHeight = card.height
   button.click()
   wait(350)
   verify(card.height > collapsedHeight, "Expanded message did not grow")
   compare(button.text, "Show less")
   verifyGeometry()
   button.click()
   wait(350)
   compare(card.height, collapsedHeight)
   verifyGeometry()
   button.click()
   model.setProperty(0, "body", "Replacement short message")
   wait(350)
   verify(!button.visible, "Short replacements should clear expansion state")
  }
  function test_compactThirdNotification() {
   const model = Config.NotificationDaemon.notificationModel
   model.append(row(201))
   model.append(row(202))
   wait(350)
   const view = list()
   const background = view.parent.parent
   const before = background.height
   model.append(row(203))
   wait(350)
   const third = view.itemAtIndex(2)
   verify(!!third)
   compare(background.height, Math.min(Config.Theme.notificationHeight,
       before + third.height + view.spacing))
   verify(background.height < Config.Theme.notificationHeight, "Three short cards should fit compactly")
   model.remove(2)
   wait(350)
   compare(background.height, before)
  }
  function test_heightStableWhileScrolling() {
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 60; i++) {
    const data = row(i, i % 3 ? "Short" : longBody.repeat(4))
    data.summary = i % 3 ? "Brief" : longBody.repeat(3)
    model.append(data)
   }
   wait(350)
   const view = list()
   const background = view.parent.parent
   const bridge = background.parent
   const height = background.height
   const inputHeight = bridge.height
   compare(height, Math.min(Config.Theme.notificationHeight, drawer.height - drawer.drawerY - 8))
   for (let i = 0; i < view.count; i += 3) {
    view.positionViewAtIndex(i, ListView.Beginning)
    wait(30)
    compare(background.height, height)
    compare(bridge.height, inputHeight)
   }
  }
  function test_resizeScrolledThenShrink() {
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 40; i++) model.append(row(i, i < 3 ? "Short" : longBody.repeat(i % 5 + 1)))
   wait(350)
   const view = list()
   keyClick(Qt.Key_End)
   wait(200)
   const last = view.itemAtIndex(39)
   verify(!!last)
   verify(last.y + last.height <= view.contentY + view.height + 1, "End must expose the real last row")
   drawer.width = 340
   wait(350)
   model.remove(3, 37)
   wait(450)
   verify(view.atYBeginning && view.atYEnd, "Remaining short rows must fit after resize/removal")
   verify(view.parent.parent.height < Config.Theme.notificationHeight, "Unknown offscreen heights must not lock drawer at maximum")
   verifyGeometry()
  }
  function test_keyboardScroll() {
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 15; i++) model.append(row(i, i % 2 ? longBody : "Short"))
   wait(350)
   const view = list()
   view.positionViewAtBeginning()
   const start = view.contentY
   keyClick(Qt.Key_PageDown)
   wait(100)
   verify(view.contentY > start, "Page Down should scroll the pinned panel")
   keyClick(Qt.Key_PageUp)
   wait(100)
   verify(Math.abs(view.contentY - start) < 1)
   keyClick(Qt.Key_End)
   wait(150)
   verify(view.atYEnd, "End should reach the last notification")
   keyClick(Qt.Key_Home)
   wait(150)
   verify(view.atYBeginning)
   Config.NotificationDaemon.drawerPinned = false
   keyClick(Qt.Key_PageDown)
   wait(100)
   verify(view.atYBeginning, "Hover-only drawer must not consume keyboard shortcuts")
   Config.NotificationDaemon.drawerPinned = true
  }
  function test_wheelAndClear() {
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 15; i++) model.append(row(i))
   wait(350)
   const view = list()
   view.positionViewAtBeginning()
   const start = view.contentY
   mouseWheel(view, 100, 100, 0, -120)
   wait(350)
   verify(view.contentY > start + 50, "Wheel should scroll the notification list")
   mouseWheel(view, 100, 100, 0, -120)
   wait(40)
   const beforeReverse = view.contentY
   mouseWheel(view, 100, 100, 0, 120)
   wait(100)
   verify(view.contentY < beforeReverse, "Wheel reversal should respond immediately")
   model.clear()
   wait(250)
   model.append(row(80))
   wait(350)
   verify(view.atYBeginning && view.atYEnd, "Clear must not leave a new notification scrolled out of view")
   verifyGeometry()
  }
  function test_failedIcon() {
   const model = Config.NotificationDaemon.notificationModel
   const data = row(70)
   data.iconSource = "file:///qs-notification-test-missing-icon.png"
   ignoreWarning(/.*Cannot open: file:.*qs-notification-test-missing-icon.png.*/)
   model.append(data)
   wait(350)
   const card = list().itemAtIndex(0)
   const icon = descendants(card).find(item => typeof item.sourceSize !== "undefined")
   verify(!!icon)
   verify(!icon.visible, "Failed icons must not reserve an empty 48px column")
   verifyGeometry()
  }
  function test_newestVisibleAtTop() {
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 10; i++) model.append(row(i))
   wait(350)
   const view = list()
   view.positionViewAtBeginning()
   model.insert(0, row(20, longBody))
   wait(350)
   verify(view.itemAtIndex(0).y >= view.contentY - 1, "New notification hidden above the viewport")
  }
  function test_longLabels() {
   drawer.width = 320
   const model = Config.NotificationDaemon.notificationModel
   const data = row(50)
   data.appName = "An extremely long application name that should never hide the dismiss button"
   model.append(data)
   Config.NotificationDaemon.actions = ({50: [{text: "Activate"}, {text: "A very long action label that cannot fit on a single row"}]})
   wait(350)
   const card = list().itemAtIndex(0)
   for (const child of descendants(card)) {
    if (!child.visible || typeof child.click !== "function") continue
    const left = child.mapToItem(card, 0, 0).x
    verify(left >= 11 && left + child.width <= card.width - 11,
     "Button outside card: " + child.hint + " x=" + left + " width=" + child.width + " card=" + card.width)
    if (child.text === "Activate") {
     compare(child.width, child.implicitWidth, "Short action should fit naturally")
     const label = descendants(child).find(item => item.text === "Activate" && typeof item.truncated === "boolean")
     verify(!!label && !label.truncated, "Short action text should not be elided")
    }
   }
   verifyGeometry()
  }
  function test_hiddenBurst() {
   Config.NotificationDaemon.isDrawerOpen = false
   wait(300)
   const model = Config.NotificationDaemon.notificationModel
   for (let i = 0; i < 12; i++) {
    model.insert(0, row(i, i % 2 ? longBody : "Short body"))
    wait(20)
   }
   Config.NotificationDaemon.actions = ({11: [{text: "Activate"}, {text: "A long secondary action"}, {text: "Another action"}]})
   Config.NotificationDaemon.isDrawerOpen = true
   wait(500)
   verifyGeometry()
  }
 }
}
''')
    result = subprocess.run([qmltestrunner(), '-input', str(p / 'tst_layout.qml')],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=30)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
