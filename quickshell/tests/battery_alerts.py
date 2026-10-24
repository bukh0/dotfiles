"""Exercise threshold crossings, charge reset and transient battery loss."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
from qt_tools import qmltestrunner
ROOT=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-battery-alerts-') as directory:
 p=Path(directory)
 source=(ROOT/'components/BatteryAlerts.qml').read_text()
 source=re.sub(r'^import Quickshell.*\n','',source,flags=re.M).replace('PersistentProperties {','QtObject {').replace('        onLoaded: evaluate.restart()\n','')
 source=source.replace('id: root','id: root\n    property var alerts: []',1).replace('Quickshell.execDetached([','root.alerts = root.alerts.concat([[').replace('"% remaining. Connect the charger."])','"% remaining. Connect the charger."]])')
 (p/'BatteryAlerts.qml').write_text(source)
 (p/'qmldir').write_text('singleton UPower 1.0 UPower.qml\n')
 (p/'UPower.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property bool onBattery: true
 property QtObject displayDevice: QtObject { property bool ready:true; property bool isPresent:true; property real percentage:0.50 }
}
''')
 (p/'tst_battery.qml').write_text('''import QtQuick
import QtTest
Item {
 BatteryAlerts {id: battery}
 TestCase { name:"BatteryAlerts"; when:windowShown
  function test_thresholds() {
   UPower.displayDevice.percentage=.15; wait(300)
   compare(battery.alerts.length,1)
   UPower.displayDevice.percentage=.14; wait(300); compare(battery.alerts.length,1)
   UPower.displayDevice.percentage=.05; wait(300); compare(battery.alerts.length,2)
   UPower.displayDevice.ready=false; wait(300)
   UPower.displayDevice.ready=true; wait(300); compare(battery.alerts.length,2)
   UPower.onBattery=false; wait(300); compare(battery.alerts.length,2)
   UPower.onBattery=true; wait(300); compare(battery.alerts.length,3)
   UPower.displayDevice.percentage=.50; wait(300)
   UPower.displayDevice.percentage=.04; wait(300); compare(battery.alerts.length,4)
   verify(battery.alerts[3].includes("Battery critically low"))
  }
 }
}
''')
 r=subprocess.run([qmltestrunner(),'-input',str(p/'tst_battery.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=10)
 assert r.returncode==0,r.stdout+r.stderr
 print('PASS single alerts per discharge cycle, 15%/5%, absent device and charging reset')
