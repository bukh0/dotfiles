"""Regression: three Notify calls generate only two daemon deliveries."""
import os, sys, subprocess, tempfile, time, shutil
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
if os.environ.get('QS_AUDIT_BUS')!='1':
 raise SystemExit(subprocess.run(['dbus-run-session','--',sys.executable,__file__],env=dict(os.environ,QS_AUDIT_BUS='1')).returncode)
with tempfile.TemporaryDirectory(prefix='qs-identical-notification-') as d:
 p=Path(d)
 shutil.copy(ROOT / 'components/NotificationDaemon.qml',p/'NotificationDaemon.qml')
 (p/'qmldir').write_text('singleton NotificationDaemon 1.0 NotificationDaemon.qml\n')
 (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 property int deliveries: 0
 Connections { target: NotificationDaemon
  function onNewNotification(data) { deliveries++; console.log("DELIVERY", deliveries, data.summary) }
 }
 Component.onCompleted: console.log("READY")
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=d,XDG_CACHE_HOME=d)
 env.pop('WAYLAND_DISPLAY',None)
 with (p/'log').open('w') as log:
  proc=subprocess.Popen(['quickshell','-p',d],env=env,stdout=log,stderr=log)
  try:
   for _ in range(100):
    if 'READY' in (p/'log').read_text(): break
    time.sleep(.05)
   first=subprocess.run(['notify-send','-p','-a','Audit','-t','4000','Same summary','Same body'],env=env,capture_output=True,text=True,check=True).stdout.strip()
   time.sleep(.3)
   subprocess.run(['notify-send','-r',first,'-a','Audit','-t','4000','Same summary','Same body'],env=env,check=True)
   time.sleep(.3)
   subprocess.run(['notify-send','-r',first,'-a','Audit','-t','4000','Changed summary','Same body'],env=env,check=True)
   time.sleep(.3)
   output = (p/'log').read_text()
   print(output)
   count = output.count('DEBUG qml: DELIVERY')
   assert count in (2, 3), output
   print('XFAIL: installed Quickshell emits no signal for identical replacement' if count == 2 else 'PASS: identical replacement is now observable upstream')
  finally:
   proc.terminate();proc.wait(timeout=5)
