"""Exercise daemon state and reentrant notification signals with fake transports."""
from pathlib import Path
import os
import json
import re
import subprocess
import tempfile
from qt_tools import qmltestrunner

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-notification-state-') as directory:
    p = Path(directory)
    source = (ROOT / 'components/NotificationDaemon.qml').read_text()
    source = re.sub(r'^import Quickshell.*\n', '', source, flags=re.M)
    source = re.sub(r'    property FileView _dndStore: FileView \{.*?\n    \}', '''    property QtObject _dndStore: QtObject {
        function text() { return "0" }
        function setText(value) {}
    }''', source, flags=re.S)
    source = re.sub(r'    property NotificationServer server: NotificationServer \{.*?\n    \}', '', source, flags=re.S)
    source = re.sub(r'    property IpcHandler ipc: IpcHandler \{.*?\n    \}', '', source, flags=re.S)
    source = source.replace('NotificationUrgency.Critical', '2').replace('Quickshell.iconPath(icon, true)', '""')
    (p / 'NotificationDaemon.qml').write_text(source)
    for name in ('NotificationDrawer.qml', 'NotificationPopup.qml', 'NotificationBell.qml', 'NotificationActions.qml', 'NotificationButton.qml', 'Colors.qml'):
        component = (ROOT / 'components' / name).read_text()
        if name in ('NotificationDrawer.qml', 'NotificationPopup.qml'):
            component = re.sub(r'^import Quickshell.*\n', '', component, flags=re.M)
            component = component.replace('PanelWindow {', 'Rectangle {', 1)
            component = re.sub(r'^    WlrLayershell\.\w+:.*\n', '', component, flags=re.M)
            component = re.sub(r'^    (?:anchors|margins|mask: Region) \{.*?\n    \}', '', component, flags=re.S | re.M)
            component = component.replace('NotificationUrgency.Critical', '2')
        (p / name).write_text(component)
    (p / 'Theme.qml').write_text((ROOT / 'profiles/default/Theme.qml').read_text()
        .replace('import Quickshell\n', '').replace('Quickshell.shellPath("../../native/sysmon")', '""'))
    (p / 'qmldir').write_text('singleton NotificationDaemon 1.0 NotificationDaemon.qml\nsingleton Colors 1.0 Colors.qml\nsingleton Theme 1.0 Theme.qml\n')
    (p / 'tst_state.qml').write_text('''import QtQuick
import QtTest
import "." as Config
Item {
 width: 1000; height: 800
 Config.NotificationDrawer { id: drawer; width: 1000; height: 800 }
 Config.NotificationPopup { id: popup; x: 1100; width: 400 }
 Config.NotificationBell { id: bell; x: 930; y: 0; width: 60; height: 40; z: 2 }
 TestCase {
 id: testCase
 name: "NotificationState"; when: windowShown
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
'''.replace('PREVIEW_PATH', json.dumps(os.environ.get('QS_NOTIFICATION_PREVIEW', ''))))
    result = subprocess.run([qmltestrunner(), '-input', str(p / 'tst_state.qml')],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=15)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
