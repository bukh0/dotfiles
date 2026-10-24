"""Check scan/power coordination without touching the real adapter."""
from pathlib import Path
import os
import subprocess
import tempfile
from qt_tools import qmltestrunner

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'components/BluetoothService.qml').read_text().replace("property bool nativeStatusEnabled: true", "property bool nativeStatusEnabled: false")
power = source[source.index('    function setPower('):source.index('    function toggleDevice(')]
scan = source[source.index('    function stopScan('):source.index('    Component.onCompleted:')]
with tempfile.TemporaryDirectory(prefix='qs-bluetooth-scan-') as directory:
    path = Path(directory)
    (path / 'tst_scan.qml').write_text('''import QtQuick
import QtTest
Item {
 id: root
 property bool powered: true
 property bool scanning: false
 property string actionKind: ""
 property bool acceptAction: true
 QtObject { id: scanProc; property bool running: false }
 function _startAction(kind, mac, command, args) {
  if (!acceptAction) return false
  actionKind = kind
  return true
 }
''' + power + scan + '''
 TestCase {
  name: "BluetoothScan"; when: windowShown
  function init() {
   root.powered = true; root.actionKind = ""; root.acceptAction = true; root.stopScan()
  }
  function test_powerOffCancelsScan() {
   root.scan(); verify(root.scanning); verify(scanProc.running)
   verify(root.setPower(false)); verify(!root.scanning); verify(!scanProc.running)
   root.scan(); verify(!scanProc.running, "Cannot restart while power-off is pending")
  }
  function test_externalPowerOff() {
   root.scan(); root.powered = false
   verify(!scanProc.running); verify(!root.scanning)
   root.scan(); verify(!scanProc.running)
  }
  function test_rejectedPowerActionPreservesScan() {
   root.scan(); root.acceptAction = false
   verify(!root.setPower(false)); verify(scanProc.running); verify(root.scanning)
  }
 }
}
''')
    result = subprocess.run([qmltestrunner(), '-input', str(path)],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen'), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    print(result.stdout)
    if result.returncode:
        raise SystemExit(result.returncode)
