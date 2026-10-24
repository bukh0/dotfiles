"""Persist real FileView history, restart, restore without actions, and clear."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-history-disk-') as directory:
 p=Path(directory)
 source=(ROOT/'components/NotificationDaemon.qml').read_text()
 source=re.sub(r'    property NotificationServer server: NotificationServer \{.*?\n    \}', '', source, flags=re.S)
 source=re.sub(r'    property IpcHandler ipc: IpcHandler \{.*?\n    \}', '', source, flags=re.S)
 (p/'NotificationDaemon.qml').write_text(source)
 shutil.copyfile(ROOT/'components/NotificationHistory.qml',p/'NotificationHistory.qml')
 (p/'qmldir').write_text('singleton NotificationDaemon 1.0 NotificationDaemon.qml\nNotificationHistory 1.0 NotificationHistory.qml\n')
 (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 NotificationHistory { id: history }
 property int ticks: 0
 property bool done: false
 Connections { target: NotificationDaemon; function onNewNotification(data) { console.error("DISK FAIL replayed popup") } }
 Timer { interval: 50; running: true; repeat: true; onTriggered: {
  if (++ticks > 80) { console.error("DISK FAIL timeout"); Qt.quit(); return }
  if (!history.ready) return
  if (!done) {
   const phase = Quickshell.env("TEST_PHASE")
   if (phase === "write") NotificationDaemon.notificationModel.append({notifId: 1, historyKey: "1:1000", appName: "App", summary: "Unread", body: "Body", timestamp: 1000, urgency: 1, iconSource: ""})
   else if (phase === "restore") {
    const model = NotificationDaemon.notificationModel
    if (model.count !== 1 || model.get(0).notifId >= 0 || NotificationDaemon.actionsFor(model.get(0).notifId).length !== 0) {console.error("DISK FAIL restore"); Qt.quit(); return}
    NotificationDaemon.clearAll()
   } else if (NotificationDaemon.notificationModel.count !== 0) {console.error("DISK FAIL clear"); Qt.quit(); return}
   done = true; ticks = 0
  } else if (ticks > 18) { console.log("DISK PASS"); Qt.quit() }
 } }
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory)
 for phase in ['write','restore','empty']:
  r=subprocess.run(['quickshell','-p',str(p)],env=dict(env,TEST_PHASE=phase),capture_output=True,text=True,timeout=8)
  output=r.stdout+r.stderr
  assert 'DISK PASS' in output and 'DISK FAIL' not in output,output
  saved=json.loads((p/'quickshell/notifications.json').read_text())
  assert len(saved['rows'])==(1 if phase=='write' else 0),saved
 print('PASS real disk writes, process restart, history-only restore and persisted clear')
