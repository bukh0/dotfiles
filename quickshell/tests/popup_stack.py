"""Exercise the real popup layout/state machine with isolated Qt input events."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-popup-stack-') as directory:
 p=Path(directory); profile=p/'profile';profile.mkdir()
 for name in ('NotificationPopup.qml','NotificationButton.qml','NotificationActions.qml','Colors.qml'):
  source=(ROOT/'components'/name).read_text()
  if name == 'NotificationPopup.qml':
   source=re.sub(r'^import Quickshell.*\n','',source,flags=re.M).replace('PanelWindow {','Rectangle {',1)
   source=re.sub(r'^    (?:anchors|margins) \{.*?\n    \}', '',source,flags=re.S | re.M)
   source=source.replace('NotificationUrgency.Critical','2')
  (profile/name).write_text(source)
 (profile/'Theme.qml').write_text((ROOT/'profiles/default/Theme.qml').read_text().replace('import Quickshell\n','').replace('Quickshell.shellPath("../../native/sysmon")','""'))
 (profile/'NotificationDaemon.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool doNotDisturb: false
 signal dismissPopup()
 signal notificationRemoved(int id)
 function getIconSource(data) { return "" }
 function actionsFor(id) { return [] }
 function invokeAction(id,index) {}
}
''')
 (profile/'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Colors 1.0 Colors.qml\nsingleton NotificationDaemon 1.0 NotificationDaemon.qml\n')
 (p/'tst_popup.qml').write_text('''import QtQuick
import QtTest
import "profile" as Config
Item {
 width: 800; height: 900
 Config.NotificationPopup { id: popup; x: 30; y: 30; width: 430 }
 TestCase {
  name: "PopupStack"; when: windowShown
  function entry(id, timeout, urgency) { return {notifId:id, summary:"Alert "+id, expireTimeout:timeout, urgency:urgency || 1} }
  function init() {
   mouseMove(parent, 750, 850)
   popup.dismissAll(); popup.maxVisible=3; popup.maxQueueLength=20
   popup.persistentDisplayDuration=2000
   Config.NotificationDaemon.doNotDisturb=false
  }
  function test_rapidDismiss() {
   for(let id=101;id<=103;id++) popup.showNotification(entry(id,0))
   popup.dismiss(); wait(30); popup.dismiss(); wait(30); popup.dismiss()
   wait(300)
   compare(popup.activeCount,0,"Three dismissals should dismiss three cards")
  }
  function test_oneWaitingPersistent() {
   popup.persistentDisplayDuration=60
   for(let id=201;id<=204;id++) popup.showNotification(entry(id,0))
   wait(400)
   compare(popup.activeCount,3,"One waiting card should only evict one persistent card")
  }
  function test_stackAndQueue() {
   for(let id=1;id<=5;id++) popup.showNotification(entry(id,0))
   compare(popup.activeCount,3); compare(popup.newestId(),3); compare(popup.queueCount,2)
   popup.dismiss()
   tryCompare(popup,"queueCount",1,600)
   compare(popup.activeCount,3); compare(popup.newestId(),4)
   popup.showNotification(entry(5,0,2))
   compare(popup.newestId(),5);compare(popup.queueCount,0);compare(popup._activeIndex(1),-1)
  }
  function test_replacementDuringFade() {
   popup.showNotification(entry(8,0));popup.dismiss()
   wait(60);popup.showNotification(entry(8,0));wait(300)
   compare(popup.activeCount,1);compare(popup.newestId(),8)
  }
  function test_hoverAndReplacement() {
   popup.showNotification(entry(9,800));wait(100)
   mouseMove(popup,50,30);wait(50)
   popup.showNotification(entry(9,80));wait(350)
   compare(popup.activeCount,1)
   mouseMove(parent,750,850)
   tryCompare(popup,"activeCount",0,700)
  }
  function test_persistentYields() {
   popup.maxVisible=1;popup.persistentDisplayDuration=50
   popup.showNotification(entry(10,0));popup.showNotification(entry(11,0))
   tryCompare(popup,"queueCount",0,600);compare(popup.newestId(),11)
   wait(350);compare(popup.activeCount,1)
  }
  function test_removedAndDnd() {
   for(let id=20;id<=24;id++) popup.showNotification(entry(id,0))
   Config.NotificationDaemon.notificationRemoved(24)
   compare(popup.queueCount,1)
   Config.NotificationDaemon.notificationRemoved(22)
   tryCompare(popup,"queueCount",0,600)
   compare(popup.newestId(),23)
   Config.NotificationDaemon.doNotDisturb=true
   compare(popup.activeCount,0);compare(popup.queueCount,0)
  }
  function test_limitsAndTimeouts() {
   popup.maxVisible=99;popup.maxQueueLength=2
   for(let id=30;id<=36;id++) popup.showNotification(entry(id,0))
   compare(popup.activeCount,3);compare(popup.queueCount,2);compare(popup._queue[0].notifId,35)
   popup.maxVisible=0;compare(popup.activeCount,1)
   popup.dismissAll();popup.maxVisible=3
   popup.showNotification(entry(40,40));popup.showNotification(entry(41,0))
   tryCompare(popup,"activeCount",1,600);compare(popup.newestId(),41)
  }
 }
}
''')
 result=subprocess.run([qmltestrunner(),'-input',str(p/'tst_popup.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=20)
 print(result.stdout+result.stderr)
 assert result.returncode==0
