"""Critical popup arrivals and existing alerts survive opening the drawer."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-critical-') as directory:
    stage = Path(directory) / 'profile'
    shutil.copytree(root / 'profiles/default', stage, symlinks=False)
    (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 NotificationPopupContent { id: popup }
 function require(ok, message) { if (!ok) throw new Error(message) }
 function send(id, urgency) {
  popup.showNotification({notifId: id, urgency: urgency, expireTimeout: 0, summary: "Test", body: "", actions: []}, null)
 }
 Timer { interval: 100; running: true; onTriggered: {
  send(1, 2); send(2, 1); send(3, 1); send(4, 1)
  require(popup.queueCount === 1, "Fixture did not queue")
  NotificationDaemon.isDrawerOpen = true
  require(popup.activeCount === 1 && popup.newestId() === 1 && popup.queueCount === 0, "Drawer lost critical or retained ordinary alerts")
  send(5, 1)
  require(popup.activeCount === 1, "Ordinary popup appeared over drawer")
  send(6, 2)
  require(popup.activeCount === 2 && popup.newestId() === 6, "Critical arrival dropped")
  send(6, 1)
  require(popup.closingCount === 1, "Downgraded replacement left a persistent alert")
  send(6, 2)
  require(popup.closingCount === 0, "Critical replacement did not revive alert")
  NotificationDaemon.isDrawerOpen = false
  NotificationDaemon.isDrawerOpen = true
  require(popup.activeCount === 2, "Reopening drawer lost critical alerts")
  NotificationDaemon.doNotDisturb = true
  require(popup.activeCount === 2, "DND lost critical alerts")
  NotificationDaemon.isDrawerOpen = false
  send(7, 1)
  require(popup.activeCount === 3, "Ordinary popups did not resume")
  popup.dismissAll()
  require(popup.activeCount === 0, "Explicit clear stopped working")
  console.log("CRITICAL PASS"); Qt.quit()
 } }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=directory, XDG_CACHE_HOME=directory,
               DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
    env.pop('WAYLAND_DISPLAY', None)
    try:
        result = subprocess.run(['quickshell', '-p', str(stage)], env=env, capture_output=True, text=True, timeout=8)
    except subprocess.TimeoutExpired as error:
        raise AssertionError(error.stdout) from error
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'CRITICAL PASS' in output and 'Error:' not in output, output
print('PASS critical alerts survive drawer opening and accept new arrivals')
