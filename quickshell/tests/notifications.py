#!/usr/bin/env python3
"""Notification protocol and drawer regressions on a private D-Bus session."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

if os.environ.get('QS_NOTIFICATION_TEST_BUS') != '1':
    raise SystemExit(subprocess.run(['dbus-run-session', '--', sys.executable, __file__],
        env=dict(os.environ, QS_NOTIFICATION_TEST_BUS='1')).returncode)

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-notification-test-') as directory:
    p = Path(directory)
    profile = p / 'profile'
    profile.mkdir()
    for name in ('NotificationDaemon.qml', 'NotificationPopup.qml', 'NotificationDrawer.qml', 'NotificationActions.qml', 'NotificationButton.qml', 'Colors.qml'):
        text = (ROOT / 'components' / name).read_text()
        if name in ('NotificationPopup.qml', 'NotificationDrawer.qml'):
            text = text.replace('PanelWindow {', 'Rectangle {', 1)
            text = re.sub(r'    WlrLayershell.keyboardFocus:.*', '', text)
            text = re.sub(r'    anchors \{.*?\n    \}', '', text, count=1, flags=re.S)
            text = re.sub(r'    margins \{.*?\n    \}', '', text, count=1, flags=re.S)
            text = re.sub(r'    mask: Region \{.*?\n    \}', '', text, count=1, flags=re.S)
        (profile / name).write_text(text)
    shutil.copyfile(ROOT / 'profiles/default/Theme.qml', profile / 'Theme.qml')
    (profile / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Colors 1.0 Colors.qml\nsingleton NotificationDaemon 1.0 NotificationDaemon.qml\nNotificationActions 1.0 NotificationActions.qml\nNotificationButton 1.0 NotificationButton.qml\n')
    (p / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "profile" as Config
ShellRoot {
 id: root
 property int removed: 0
 property int received: 0
 property int notificationId: -1
 property string summary: ""
 QtObject { id: monitorMarker }
 function check(ok, reason) { if (!ok) { console.error("FAIL", reason); Qt.quit() } }
 Window { id: window; visible: true; width: 1000; height: 800 }
 Config.NotificationPopup { id: popup; parent: window.contentItem; x: 1100 }
 Config.NotificationDrawer { id: drawer; parent: window.contentItem; width: 1000; height: 800 }
 Connections {
  target: Config.NotificationDaemon
  function onNotificationRemoved(id) { root.removed++ }
  function onNewNotification(data) {
   root.received++
   popup.showNotification(data)
   root.notificationId = data.notifId
   root.summary = data.summary
   if (data.summary === "action test") {
    root.check(data.expireTimeout === 8000, "Notification protocol did not supply milliseconds: " + data.expireTimeout)
    root.check(popup.displayDuration === 8000, "Notification timeout changed units")
    root.check(data.actions.length > 0, "Actions were not forwarded")
    const row = Config.NotificationDaemon.notificationModel.get(0)
    root.check(row.timestamp > 0 && row.urgency === 1, "History metadata missing")
   }
   action.restart()
  }
 }
 Timer {
  id: action; interval: 120
  onTriggered: {
   if (root.summary === "action test") {
    Config.NotificationDaemon.invokeAction(root.notificationId, 0)
    console.log("ACTION DONE")
   } else {
    Config.NotificationDaemon.closeNotificationById(root.notificationId)
    root.check(root.removed === 2, "Duplicate notificationRemoved emission")
    Config.NotificationDaemon.doNotDisturb = true
    console.log("DND READY")
   }
  }
 }
 Component.onCompleted: {
  Config.NotificationDaemon.hoverCloseDelay = 20
  Config.NotificationDaemon.beginHoverOpen()
  Config.NotificationDaemon.toggleDrawer()
  Config.NotificationDaemon.scheduleHoverClose()
 }
 Timer {
  interval: 150; running: true
  onTriggered: {
   root.check(Config.NotificationDaemon.isDrawerOpen && Config.NotificationDaemon.drawerPinned, "Hover timer closed pinned drawer")
   Config.NotificationDaemon.surfaceScreen = monitorMarker
   Config.NotificationDaemon.toggleDrawer()
   root.check(!Config.NotificationDaemon.isDrawerOpen && !Config.NotificationDaemon.drawerPinned, "Second tap did not close drawer")
   root.check(Config.NotificationDaemon.surfaceScreen === monitorMarker, "Closing drawer released monitor before fade")
   fadeCheck.start()
   console.log("READY")
  }
 }
 Timer {
  id: fadeCheck; interval: 260
  onTriggered: root.check(Config.NotificationDaemon.surfaceScreen === null, "Hidden drawer retained monitor")
 }
 Timer {
  interval: 100; running: true; repeat: true
  onTriggered: if (Config.NotificationDaemon.doNotDisturb && Config.NotificationDaemon.notificationModel.count === 1) {
   root.check(root.received === 2, "DND emitted a popup")
   root.check(!popup.isVisible, "DND left a popup visible")
   root.check(popup._durationFor({urgency: 2, expireTimeout: 8000}) === 0, "Critical notification timed out")
   console.log("NOTIFICATION PASS"); Qt.quit()
  }
 }
}
''')
    log = p / 'log'
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory)
    env.pop('WAYLAND_DISPLAY', None)
    with log.open('w') as output:
        shell = subprocess.Popen(['quickshell', '-p', str(p/'shell.qml')], env=env, stdout=output, stderr=output)
        try:
            def wait_for(marker):
                deadline = time.monotonic() + 8
                while time.monotonic() < deadline:
                    text = log.read_text()
                    if 'FAIL' in text or shell.poll() is not None:
                        if marker not in text: raise AssertionError(text)
                    if marker in text: return
                    time.sleep(0.05)
                raise AssertionError(log.read_text())
            wait_for('READY')
            action = subprocess.run(['notify-send', '--wait', '--action=open=Open', '-t', '8000', 'action test'],
                                    env=env, capture_output=True, text=True, timeout=8)
            assert action.returncode == 0 and action.stdout.strip() == 'open', (action, log.read_text())
            wait_for('ACTION DONE')
            subprocess.run(['notify-send', '-t', '8000', 'close test'], env=env, check=True)
            wait_for('DND READY')
            subprocess.run(['notify-send', '-t', '8000', 'silent test'], env=env, check=True)
            wait_for('NOTIFICATION PASS')
            shell.wait(timeout=5)
            assert 'FAIL' not in log.read_text(), log.read_text()
            print('PASS: real timeout units, notification actions, removal, pinning, and DND')
        finally:
            if 'NOTIFICATION PASS' not in log.read_text(): print(log.read_text(), flush=True)
            if shell.poll() is None: shell.terminate(); shell.wait(timeout=5)
