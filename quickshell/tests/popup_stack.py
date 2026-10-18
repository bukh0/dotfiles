"""Exercise the real popup layout/state machine with isolated Qt input events."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-popup-stack-') as directory:
 p=Path(directory); profile=p/'profile';profile.mkdir()
 for name in ('NotificationPopup.qml','NotificationButton.qml','NotificationActions.qml','Colors.qml', 'NotificationBody.js'):
  source=(ROOT/'components'/name).read_text()
  if name == 'NotificationPopup.qml':
   source=re.sub(r'^import Quickshell.*\n','',source,flags=re.M).replace('PanelWindow {','Rectangle {\n    property var screen: null',1)
   source=re.sub(r'^    (?:anchors|margins) \{.*?\n    \}', '',source,flags=re.S | re.M)
   source=re.sub(r'^    WlrLayershell\.\w+:.*\n', '', source, flags=re.M)
   source=source.replace('NotificationUrgency.Critical','2')
  (profile/name).write_text(source)
 (profile/'Theme.qml').write_text((ROOT/'profiles/default/Theme.qml').read_text().replace('import Quickshell\n','').replace('Quickshell.shellPath("../../native/sysmon")','""'))
 (profile/'NotificationDaemon.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool doNotDisturb: false
 property int invoked: 0
 signal dismissPopup()
 signal dismissPopupById(int id)
 signal notificationRemoved(int id)
 function getIconSource(data) { return "" }
 function actionsFor(id) { return [] }
 function invokeAction(id,index) { invoked++ }
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
  function descendants(item) {
   let result = []
   for (const child of item.children || []) result = result.concat([child], descendants(child))
   return result
  }
  function test_dndFiltersActiveAndQueue() {
   popup.showNotification(entry(611,0,2))
   popup.showNotification(entry(612,0))
   popup.showNotification(entry(613,0))
   popup.showNotification(entry(614,0))
   // Criticals normally bypass the queue; verify filtering preserves one too.
   popup._queue = popup._queue.concat([entry(615,0,2)])
   Config.NotificationDaemon.doNotDisturb = true
   compare(popup.queueCount,0)
   compare(popup.activeCount,2)
   verify(popup._activeIndex(611) >= 0)
   verify(popup._activeIndex(615) >= 0)
   wait(300)
   compare(popup.activeCount,2)
  }
  function test_closingCountTracksRoles() {
   popup.showNotification(entry(601,0))
   popup.showNotification(entry(602,0))
   popup._requestClose(601)
   compare(popup.closingCount,1)
   popup._requestClose(602)
   compare(popup.closingCount,2)
   popup.showNotification(entry(601,0))
   compare(popup.closingCount,1)
   wait(300)
   compare(popup.closingCount,0)
  }
  function test_screenLatchedForBurst() {
   const left = {name: "left"}, right = {name: "right"}
   popup.maxVisible = 1
   popup.showNotification(entry(401,0), left)
   compare(popup.screen, left)
   popup.showNotification(entry(402,0), right)
   compare(popup.screen, left, "queued notification must not move active cards")
   popup.showNotification(entry(401,0), right)
   compare(popup.screen, left, "replacement must not change screens")
   popup.dismiss()
   wait(300)
   compare(popup.screen, left, "queue refill stays on original screen")
   popup.dismissAll()
   popup.showNotification(entry(403,0), right)
   compare(popup.screen, right, "next burst follows current monitor")
  }
  function test_bodyLinksAreNotInertAnchors() {
   const data = entry(404,0)
   data.body = '<b>Message</b> <img alt="a > b" src="https://example.invalid/image"> <a title="a > b" href="https://example.invalid">Details</a>'
   popup.showNotification(data)
   wait(50)
   const body = descendants(popup).find(item => typeof item.text === "string" && item.text.includes("Details"))
   verify(!!body)
   compare(body.text, '<b>Message</b>  Details')
  }
  function test_actionDoesNotDismissCard() {
   const data = entry(95,0)
   data.actions = [{identifier: "default", text: "Open"}]
   popup.showNotification(data)
   wait(300)
   const button = descendants(popup).find(item => item.text === "Open" && typeof item.click === "function")
   verify(!!button)
   const before = Config.NotificationDaemon.invoked
   mouseClick(button)
   compare(Config.NotificationDaemon.invoked,before+1)
   wait(300)
   compare(popup.activeCount,1,"An action click must not also trigger the card dismissal handler")
  }
  function test_criticalEvictsNormalFirst() {
   popup.showNotification(entry(501,0,2))
   popup.showNotification(entry(502,0))
   popup.showNotification(entry(503,0))
   popup.showNotification(entry(504,0,2))
   verify(popup._activeIndex(501) >= 0, "new critical alert must preserve an existing critical alert when ordinary cards can yield")
   compare(popup._activeIndex(502), -1, "oldest ordinary card yields first")
   compare(popup.activeCount, 3)
   popup.showNotification(entry(505,0,2))
   compare(popup._activeIndex(503), -1)
   popup.showNotification(entry(506,0,2))
   compare(popup._activeIndex(501), -1, "all-critical overflow remains bounded by evicting the oldest")
  }
  function test_criticalReusesClosingSlot() {
   popup.showNotification(entry(511,0))
   popup.showNotification(entry(512,0,2))
   popup.showNotification(entry(513,0,2))
   popup._requestClose(512)
   popup.showNotification(entry(514,0,2))
   compare(popup._activeIndex(512), -1, "reuse an already closing card")
   verify(popup._activeIndex(511) >= 0, "no additional visible card needs eviction")
   wait(300)
   compare(popup.activeCount, 3, "old removal timer must not remove a new card")
  }
  function test_reducingSlotsPreservesCritical() {
   popup.showNotification(entry(521,0,2))
   popup.showNotification(entry(522,0))
   popup.showNotification(entry(523,0))
   popup.maxVisible = 1
   compare(popup.newestId(), 521)
  }
  function test_criticalDoesNotYieldToQueue() {
   popup.maxVisible=1; popup.persistentDisplayDuration=40
   popup.showNotification(entry(90,0,2))
   popup.showNotification(entry(91,0))
   wait(400)
   compare(popup.newestId(),90,"A normal queued notification must not time out a critical alert")
   compare(popup.queueCount,1)
   popup.dismiss()
   tryCompare(popup,"queueCount",0,600)
   compare(popup.newestId(),91)
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
