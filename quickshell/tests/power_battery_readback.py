from pathlib import Path
import os, subprocess, tempfile, shutil
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-review-') as d:
 p=Path(d); (p/'.scripts').mkdir(); (p/'bin').mkdir()
 (p/'.scripts/toggle-performance.sh').write_text('set -e\nsudo first\nif [[ ${SECOND:-0} == 1 ]]; then sudo second; fi\n')
 (p/'bin/sudo').write_text('''#!/bin/bash
if [[ $2 == first && ${SECOND:-0} == 1 ]]; then exit 0; fi
if [[ ${MOCK_FAIL:-0} == 1 ]]; then exit 5; fi
"$SUDO_ASKPASS" >/dev/null || exit 1
''')
 (p/'bin/zenity').write_text('#!/bin/sh\nexit "${ZENITY_STATUS:-0}"\n')
 for f in (p/'bin').iterdir(): f.chmod(0o755)
 for z,fail,second,expected in [(0,0,0,0),(1,0,0,130),(2,0,0,1),(0,1,0,5),(1,0,1,1)]:
  env=dict(os.environ,HOME=d,TMPDIR=d,PATH=str(p/'bin')+':'+os.environ['PATH'],ZENITY_STATUS=str(z),MOCK_FAIL=str(fail),SECOND=str(second))
  r=subprocess.run(['bash',str(ROOT/'native/toggle-performance.sh')],env=env,capture_output=True,text=True)
  assert r.returncode==expected,(z,fail,second,r.returncode,r.stderr)
  assert not list(p.glob('qs-performance.*'))
 print('PASS profile success, cancellation, dialog error, sudo failure, partial-change cancellation and cleanup')
 # Real QML battery component, with only native UPower replaced by a local stub.
 src=(ROOT/'components/BatteryIndicator.qml').read_text().replace('import Quickshell.Services.UPower','')
 (p/'BatteryIndicator.qml').write_text(src)
 (p/'qmldir').write_text('\n'.join('singleton '+n+' 1.0 '+n+'.qml' for n in ['UPower','UPowerDeviceState','Colors','Theme']))
 (p/'UPowerDeviceState.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { enum State { Charging, FullyCharged, PendingCharge, Discharging } }')
 (p/'UPower.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property QtObject displayDevice: QtObject { property bool ready:true; property bool isPresent:true; property real percentage:0.05; property int state: UPowerDeviceState.PendingCharge } }')
 (p/'Colors.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property color primary:"blue"; property color error:"red"; property color tertiary:"orange"; property color surfaceFg:"white" }')
 (p/'Theme.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property int fontSizeMD:12; property string fontMono:"monospace" }')
 (p/'tst_battery.qml').write_text('''import QtQuick
import QtTest
Item {
 BatteryIndicator { id: battery }
 TestCase {
  name:"Battery"; when:windowShown
  function test_pendingCharge() {
   compare(battery.status,"Not charging"); verify(battery.isCritical); compare(battery.iconColor,Colors.error)
   const plug=battery.icon
   UPower.displayDevice.percentage=0.15; verify(battery.isLow); verify(!battery.isCritical)
   UPower.displayDevice.percentage=0.5; verify(!battery.isLow); compare(battery.icon,plug)
   UPower.displayDevice.percentage=0.05; UPower.displayDevice.state=UPowerDeviceState.Charging
   verify(!battery.isCritical); compare(battery.iconColor,Colors.primary)
  }
 }
}''')
 runner='/usr/lib/qt6/bin/qmltestrunner'
 r=subprocess.run([runner,'-input',str(p/'tst_battery.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=d),capture_output=True,text=True)
 assert r.returncode==0,r.stdout+r.stderr
 print('PASS PendingCharge critical/low warnings, plug icon and charging suppression')
 # Real FileView lifecycle against a temporary writable mock backlight.
 src=(ROOT/'components/BrightnessService.qml').read_text().replace('"/sys/class/backlight/"','"'+d+'/"')
 (p/'BrightnessService.qml').write_text(src)
 with (p/'qmldir').open('a') as f:f.write('\nsingleton BrightnessService 1.0 BrightnessService.qml\n')
 (p/'mock').mkdir()
 (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "."
ShellRoot {
 Component.onCompleted: {
  BrightnessService.device="mock"; BrightnessService.maxRaw=100; BrightnessService.available=true
 }
 Timer { interval:60; running:true; onTriggered: {
  if (!BrightnessService.available || BrightnessService.device !== "mock") {console.log("FAIL transient read dropped device");Qt.quit();return}
  restore.running=true
 } }
 Process { id:restore; command:["sh","-c","echo 42 > '''+d+'''/mock/brightness"] }
 Timer { interval:600; running:true; onTriggered: {
  if (!BrightnessService.available || BrightnessService._readFailures !== 0 || BrightnessService.brightness !== 0.42) {
   console.log("FAIL transient recovery");Qt.quit();return
  }
  BrightnessService.device="missing"
 } }
 Timer { interval:1300; running:true; onTriggered: {
  if (BrightnessService.available || BrightnessService.device !== "") console.log("FAIL permanent loss did not clear device")
  else console.log("BRIGHTNESS RETRY PASS")
  Qt.quit()
 } }
}''')
 r=subprocess.run(['quickshell','-p',str(p/'shell.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=d),capture_output=True,text=True,timeout=5)
 assert 'BRIGHTNESS RETRY PASS' in r.stdout+r.stderr,r.stdout+r.stderr
 print('PASS transient FileView recovery and permanent device loss')
