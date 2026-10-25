"""Exercise daemon state and reentrant notification signals with fake transports."""
from pathlib import Path
import os
import json
import re
import subprocess
import tempfile
from qt_tools import qmltestrunner
from harness import stub_colors

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-notification-state-') as directory:
    p = Path(directory)
    icon_path = p / 'icon#100% ?é.svg'
    icon_path.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>')
    source = (ROOT / 'components/NotificationDaemon.qml').read_text()
    source = re.sub(r'^import Quickshell.*\n', '', source, flags=re.M)
    source = re.sub(r'    property FileView _dndStore: FileView \{.*?\n    \}', '''    property QtObject _dndStore: QtObject {
        function text() { return "0" }
        property string written: ""
        function setText(value) { written=value }
    }''', source, flags=re.S)
    if os.environ.get('QS_TEST_DND_THROW') == '1':
        source = source.replace('function text() { return "0" }', 'function text() { throw new Error("missing file") }')
    source = re.sub(r'    property NotificationServer server: NotificationServer \{.*?\n    \}', '', source, flags=re.S)
    source = re.sub(r'    property IpcHandler ipc: IpcHandler \{.*?\n    \}', '', source, flags=re.S)
    source = source.replace('NotificationUrgency.Critical', '2').replace('Quickshell.iconPath(icon, true)', '""')
    (p / 'NotificationDaemon.qml').write_text(source)
    for name in ("PlainToolTip.qml", 'NotificationDrawer.qml', 'NotificationPopup.qml', 'NotificationBell.qml', 'NotificationActions.qml', 'NotificationButton.qml', 'Colors.qml', 'NotificationBody.js'):
        component = (ROOT / "components" / name.replace("NotificationPopup.qml", "NotificationPopupContent.qml").replace("NotificationDrawer.qml", "NotificationDrawerContent.qml")).read_text()
        component = component.replace('id: hoverBridge', 'id: hoverBridge; objectName: "auditBridge"')
        (p / name).write_text(component)
    stub_colors(p / "Colors.qml")
    (p / "BaseTheme.qml").write_text((ROOT / "components/BaseTheme.qml").read_text().replace("import Quickshell\n", ""))
    (p / 'Theme.qml').write_text((ROOT / 'profiles' / os.environ.get('QS_TEST_PROFILE', 'default') / 'Theme.qml').read_text()
        .replace('import Quickshell\n', '').replace('Quickshell.shellPath("../../native/sysmon")', '""'))
    (p / 'qmldir').write_text('PlainToolTip 1.0 PlainToolTip.qml\nsingleton NotificationDaemon 1.0 NotificationDaemon.qml\nsingleton Colors 1.0 Colors.qml\nBaseTheme 1.0 BaseTheme.qml\nsingleton Theme 1.0 Theme.qml\n')
    (p / 'tst_state.qml').write_text('''import QtQuick
import QtTest
import "." as Config
Item {
 width: 1000; height: 800
 Image { id: pathImage }
 Config.NotificationDrawer { id: drawer; width: 1000; height: 800 }
 Config.NotificationPopup { id: popup; x: 1100; width: 400 }
 Config.NotificationBell { id: bell; x: 930; y: (Config.Theme.barTotalHeight - height) / 2; width: 60; height: 30; z: 2; hoverBottomMargin: Math.max(0, (Config.Theme.barTotalHeight - height) / 2) }
 TestCase {
 id: testCase
 name: "NotificationState"; when: windowShown
 function test_dndInitializationPersists() {
  verify(Config.NotificationDaemon._dndReady)
  Config.NotificationDaemon.doNotDisturb = !Config.NotificationDaemon.doNotDisturb
  compare(Config.NotificationDaemon._dndStore.written, Config.NotificationDaemon.doNotDisturb ? "1\\n" : "0\\n")
 }
 property int observedId: -1
 property var observedActions: Config.NotificationDaemon.actionsFor(observedId)
 property var removedActions: null
 property var lastDelivery: null
 property int delivered: 0
 property int removed: 0
 Connections {
  target: Config.NotificationDaemon
  function onNewNotification(data) { testCase.delivered++; testCase.lastDelivery = data; popup.showNotification(data) }
  function onNotificationRemoved(id) {
   testCase.removed++
   testCase.removedActions = Config.NotificationDaemon.actionsFor(id)
  }
 }
 function signal() {
  return {callbacks: [], connect: function(fn) { this.callbacks.push(fn) },
   emit: function() { for (const fn of this.callbacks.slice()) fn() }}
 }
 function notification(id) {
  const n = {id: id, tracked: false, lastGeneration: false, summary: "Alert " + id,
   body: "Body", appName: "Test", appIcon: "", image: "", urgency: 1, expireTimeout: 0,
   actions: [{text: "Open", invoke: function() {}}]}
  for (const name of ["summary", "body", "appName", "appIcon", "image", "urgency", "expireTimeout", "actions"])
   n[name + "Changed"] = signal()
  n.closed = signal()
  n.dismiss = function() { this.closed.emit() }
  return n
 }
 function init() {
  mouseMove(parent, 5, 700)
  Config.NotificationDaemon.clearAll()
  popup.dismissAll()
  Config.NotificationDaemon.maxNotifications = 50
  Config.NotificationDaemon.doNotDisturb = false
  Config.NotificationDaemon.isDrawerOpen = false
  Config.NotificationDaemon.hoverCloseDelay = 20
  Config.NotificationDaemon.restoreTimestamps("{}")
  observedId = -1; removedActions = null; delivered = 0; removed = 0
 }
 function test_pinnedMonitorAndFadeReopen() {
  const first = {name:"A"}, second = {name:"B"}
  bell.screen = second
  Config.NotificationDaemon.surfaceScreen = first
  Config.NotificationDaemon.isDrawerOpen = true
  Config.NotificationDaemon.drawerPinned = true
  mouseMove(bell, bell.width / 2, bell.height / 2)
  wait(50)
  compare(Config.NotificationDaemon.surfaceScreen,first)
  mouseMove(parent,5,700)
  Config.NotificationDaemon.isDrawerOpen = false
  wait(50)
  mouseMove(bell,bell.width / 2,bell.height / 2)
  wait(250)
  verify(Config.NotificationDaemon.isDrawerOpen)
  compare(Config.NotificationDaemon.surfaceScreen,second)
 }
 function test_clickOtherMonitorKeepsClosingDrawerOnOriginalScreen() {
  const first = {name:"A"}, second = {name:"B"}
  bell.screen = second
  Config.NotificationDaemon.surfaceScreen = first
  Config.NotificationDaemon.isDrawerOpen = true
  Config.NotificationDaemon.drawerPinned = true
  wait(250)
  mouseClick(bell, bell.width / 2, bell.height / 2)
  verify(!Config.NotificationDaemon.isDrawerOpen)
  compare(Config.NotificationDaemon.surfaceScreen, first)
 }
 function test_dndPreservesCritical() {
  const critical = notification(701)
  critical.urgency = 2
  Config.NotificationDaemon._receiveNotification(critical)
  const normal = notification(702)
  Config.NotificationDaemon._receiveNotification(normal)
  Config.NotificationDaemon.setDnd(true)
  compare(popup.activeCount,1)
  compare(popup.newestId(),Config.NotificationDaemon._serverIds[701])
  wait(300)
  compare(popup.activeCount,1,"daemon must not dismiss the surviving critical")
  compare(Config.NotificationDaemon.notificationModel.count,2)
 }
 function test_replacementMovesToTop() {
  const first = notification(711), second = notification(712)
  Config.NotificationDaemon._receiveNotification(first)
  wait(5)
  Config.NotificationDaemon._receiveNotification(second)
  first.summary = "Updated"
  first.summaryChanged.emit()
  wait(20)
  const model = Config.NotificationDaemon.notificationModel
  compare(model.count,2)
  compare(model.get(0).notifId,Config.NotificationDaemon._serverIds[711])
  compare(model.get(0).summary,"Updated")
  verify(model.get(0).timestamp >= model.get(1).timestamp)
 }
 function test_hiddenBarOffsets() {
  drawer.barHeight = 0
  compare(drawer.drawerY,4)
  compare(findChild(drawer,"auditBridge").y,0)
  drawer.barHeight = Config.Theme.barTotalHeight
 }
 function test_localImagePaths() {
  const path = ICON_PATH
  const url = ICON_URL
  for (const data of [{image: path}, {appIcon: path}]) {
   compare(Config.NotificationDaemon.getIconSource(data), url)
   pathImage.source = Config.NotificationDaemon.getIconSource(data)
   tryCompare(pathImage, "status", Image.Ready)
  }
  compare(Config.NotificationDaemon.getIconSource({image: url}), url)
  compare(Config.NotificationDaemon.getIconSource({appIcon: url}), url)
  compare(Config.NotificationDaemon.getIconSource({image: "image://provider/icon"}), "image://provider/icon")
 }
 function test_imageWithQuotedGreaterThan() {
  const n = notification(602)
  n.body = 'Before<img alt="a > b" src="https://example.invalid/image">after'
  Config.NotificationDaemon._receiveNotification(n)
  compare(Config.NotificationDaemon.notificationModel.get(0).body, "Beforeafter")
 }
 function test_timestampsLoadedAfterDelivery() {
  const older = notification(801), newer = notification(802), fresh = notification(803)
  older.lastGeneration = true; newer.lastGeneration = true
  Config.NotificationDaemon._receiveNotification(older)
  Config.NotificationDaemon._receiveNotification(newer)
  Config.NotificationDaemon._receiveNotification(fresh)
  const freshTime = Config.NotificationDaemon.timestamps[803]
  Config.NotificationDaemon.restoreTimestamps('{"801":200,"802":100,"803":50}')
  const model = Config.NotificationDaemon.notificationModel
  compare(model.get(0).notifId, Config.NotificationDaemon._serverIds[803])
  compare(model.get(0).timestamp, freshTime)
  compare(model.get(1).timestamp, 200)
  compare(model.get(2).timestamp, 100)
  Config.NotificationDaemon.restoreTimestamps('invalid')
  compare(Config.NotificationDaemon.timestamps[803], freshTime)
  older.summary = "Replacement"
  Config.NotificationDaemon._receiveNotification(older)
  const replacementTime = Config.NotificationDaemon.timestamps[801]
  Config.NotificationDaemon.restoreTimestamps('{"801":1}')
  compare(Config.NotificationDaemon.timestamps[801], replacementTime)
  compare(model.get(0).timestamp, replacementTime)
 }
 function test_invalidSavedTimestamps() {
  for (const saved of ["null", "[]", "42", '{"601": 1e999}', '{"601": 9e15}', '"invalid"', '{"601": "yesterday"}']) {
   Config.NotificationDaemon.restoreTimestamps(saved)
   const n = notification(601)
   n.lastGeneration = true
   Config.NotificationDaemon._receiveNotification(n)
   compare(Config.NotificationDaemon.notificationModel.count, 1)
   const timestamp = Config.NotificationDaemon.notificationModel.get(0).timestamp
   verify(Number.isFinite(timestamp), "invalid saved state must fall back to a valid timestamp")
   Config.NotificationDaemon.clearAll()
  }
 }
 function test_lateHoverClose() {
  Config.NotificationDaemon.beginHoverOpen()
  wait(250)
  mouseMove(parent, 800, 150)
  wait(30)
  // The bell's leave event can arrive after the drawer's enter event.
  Config.NotificationDaemon.scheduleHoverClose()
  wait(60)
  verify(Config.NotificationDaemon.isDrawerOpen,"Late bell leave event closed a hovered drawer")
  mouseMove(parent, 5, 700)
  wait(60)
  verify(!Config.NotificationDaemon.isDrawerOpen)
 }
 function test_bellBottomMarginHoverAndPin() {
  mouseMove(parent, bell.x + bell.width / 2, Config.Theme.barTotalHeight - 1)
  wait(50)
  verify(Config.NotificationDaemon.isDrawerOpen, "bottom bar margin must open drawer")
  compare(Config.NotificationDaemon.hoveredTrigger, bell)
  mouseClick(parent, bell.x + bell.width / 2, Config.Theme.barTotalHeight - 1)
  verify(Config.NotificationDaemon.drawerPinned, "bell margin clicks must retain normal pin behavior")
 }
 function test_drawerHorizontalPadding() {
  Config.NotificationDaemon.beginHoverOpen()
  wait(250)
  const bridge = findChild(drawer, "auditBridge")
  mouseMove(drawer, bridge.x + 1, Config.Theme.barTotalHeight + 30)
  wait(60)
  verify(Config.NotificationDaemon.isDrawerOpen, "padded left edge keeps drawer open")
  mouseMove(parent, 5, 700)
  wait(60)
  verify(!Config.NotificationDaemon.isDrawerOpen)
 }
 function test_hoverGapClickDoesNotDismiss() {
  Config.NotificationDaemon.beginHoverOpen()
  wait(250)
  mouseClick(drawer, 800, Config.Theme.barTotalHeight + 2)
  verify(Config.NotificationDaemon.isDrawerOpen, "hover-only bridge clicks must not hit outside dismissal")
 }
 function test_hoverOnlyEscape() {
  Config.NotificationDaemon.beginHoverOpen()
  wait(250)
  keyClick(Qt.Key_Escape)
  verify(Config.NotificationDaemon.isDrawerOpen, "hover-only drawer must not claim Escape")
 }
 function test_bridgeDoesNotFollowSlide() {
  wait(250)
  Config.NotificationDaemon.beginHoverOpen()
  wait(30)
  const bridge = findChild(drawer, "auditBridge")
  const height = bridge.height
  wait(90)
  compare(bridge.height, height, "input height must not follow visual slide animation")
 }
 function test_hoverGap() {
  Config.NotificationDaemon.beginHoverOpen()
  wait(250)
  mouseMove(parent, 800, Config.Theme.barTotalHeight + 2)
  wait(30)
  Config.NotificationDaemon.scheduleHoverClose()
  wait(60)
  verify(Config.NotificationDaemon.isDrawerOpen,"Gap below bell must keep the panel open")
 }
 function test_returnToBell() {
  Config.NotificationDaemon.beginHoverOpen()
  wait(250)
  mouseMove(bell, 20, 20)
  wait(30)
  Config.NotificationDaemon.scheduleHoverClose()
  wait(60)
  verify(Config.NotificationDaemon.isDrawerOpen,"Late drawer leave event closed a hovered bell")
 }
 function descendants(item) {
  let result = []
  for (const child of item.children || []) result = result.concat([child], descendants(child))
  return result
 }
 function test_unnamedActions() {
  const n = notification(30)
  n.appName = "kitty"; n.summary = "Task complete"; n.body = "The notification panel is ready to review."
  n.invocations = 0
  n.actions = [{identifier: "default", text: "  ", invoke: function() { n.invocations++ }},
   {identifier: "later", text: "Remind me later", invoke: function() {}}]
  Config.NotificationDaemon._receiveNotification(n)
  compare(lastDelivery.actions[0].text,"Open","Unnamed default action needs a useful label in popups")
  Config.NotificationDaemon.toggleDrawer()
  wait(250)
  const button = descendants(drawer).find(item => item.text === "Open" && typeof item.click === "function")
  verify(!!button && button.visible,"Drawer must render the default action with a label")
  const view = descendants(drawer).find(item => typeof item.itemAtIndex === "function")
  const scrollbar = descendants(view).find(item => typeof item.policy !== "undefined" && typeof item.size === "number")
  verify(!scrollbar.visible,"A notification that fits must not show a scrollbar")
  mouseClick(button)
  compare(n.invocations,1,"Normalizing labels must preserve the action index")
  if (PREVIEW_PATH) {
   mouseMove(parent, 5, 700)
   wait(150)
   grabImage(drawer).save(PREVIEW_PATH)
  }
  n.actions = [{identifier: "unknown", text: "", invoke: function() {}}]
  n.actionsChanged.emit()
  wait(30)
  compare(lastDelivery.actions[0].text,"Action 1","Other unnamed actions must not render empty squares")
 }
 function test_dndReplacementOfCritical() {
  Config.NotificationDaemon.doNotDisturb = true
  const n = notification(40)
  n.urgency = 2
  Config.NotificationDaemon._receiveNotification(n)
  compare(popup.activeCount,1,"Critical notifications may bypass DND")
  n.urgency = 1; n.urgencyChanged.emit()
  n.body = "Normal update"; n.bodyChanged.emit()
  wait(300)
  compare(popup.activeCount,0,"DND must hide a formerly critical popup when it becomes normal")
  compare(Config.NotificationDaemon.notificationModel.count,1,"DND must keep history")
  compare(Config.NotificationDaemon.notificationModel.get(0).body,"Normal update")
 }
 function test_cleanupBeforeSignal() {
  const n = notification(1)
  Config.NotificationDaemon._receiveNotification(n)
  observedId = Config.NotificationDaemon.notificationModel.get(0).notifId
  compare(observedActions.length,1)
  n.closed.emit()
  compare(removedActions.length,0,"Removal listeners must not see actions belonging to a closed notification")
  compare(observedActions.length,0,"Action bindings must invalidate after cleanup")
  compare(removed,1)
 }
 function test_closeDuringQueuedReplacement() {
  const n = notification(2)
  Config.NotificationDaemon._receiveNotification(n)
  n.body = "Changed"; n.bodyChanged.emit()
  n.closed.emit()
  wait(30)
  compare(Config.NotificationDaemon.notificationModel.count,0)
  compare(delivered,1,"A queued update must not resurrect a closed notification")
  compare(removed,1)
 }
 function test_coalescedReplacement() {
  const n = notification(3)
  Config.NotificationDaemon._receiveNotification(n)
  n.body = "Changed"; n.bodyChanged.emit()
  n.summary = "Updated"; n.summaryChanged.emit()
  n.actions = []; n.actionsChanged.emit()
  wait(30)
  compare(delivered,2)
  compare(Config.NotificationDaemon.notificationModel.count,1)
  compare(Config.NotificationDaemon.notificationModel.get(0).summary,"Updated")
 }
 function test_orphanCloserCleanup() {
  const daemon = Config.NotificationDaemon
  daemon._closers[98765] = function() { fail("forget must not invoke a closer") }
  const revision = daemon.actionRevision
  daemon._forgetLocalId(98765)
  verify(!Object.prototype.hasOwnProperty.call(daemon._closers, 98765))
  compare(daemon.actionRevision, revision)
 }
 function test_historyOverflow() {
  Config.NotificationDaemon.maxNotifications = 2
  for (let i = 0; i < 5; i++) Config.NotificationDaemon._receiveNotification(notification(10+i))
  compare(Config.NotificationDaemon.notificationModel.count,2)
  compare(Object.keys(Config.NotificationDaemon._serverObjects).length,2)
  compare(Object.keys(Config.NotificationDaemon._closers).length,2)
  compare(Object.keys(Config.NotificationDaemon.timestamps).length,2)
  compare(removed,3)
  Config.NotificationDaemon.clearAll()
  compare(removed,5)
  compare(Object.keys(Config.NotificationDaemon.timestamps).length,0)
 }
 }
}
'''.replace('PREVIEW_PATH', json.dumps(os.environ.get('QS_NOTIFICATION_PREVIEW', '')))
   .replace('ICON_PATH', json.dumps(str(icon_path))).replace('ICON_URL', json.dumps(icon_path.as_uri())))
    result = subprocess.run([qmltestrunner(), '-input', str(p / 'tst_state.qml')],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=15)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
