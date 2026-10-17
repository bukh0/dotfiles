"""Check Bluetooth device visibility without accessing Bluetooth hardware."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="qs-bluetooth-devices-") as directory:
    stage = Path(directory)
    source = (ROOT / "components/BluetoothService.qml").read_text()
    source = source.replace("running: true", "running: false")
    source = source.replace("Component.onCompleted: root.refresh()", "Component.onCompleted: {}")
    (stage / "BluetoothService.qml").write_text(source)
    (stage / "qmldir").write_text("singleton BluetoothService 1.0 BluetoothService.qml\n")
    (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Component.onCompleted: {
  const objects = {"/org/bluez/hci0": {"org.bluez.Adapter1": {Powered: {data: true}}}}
  function add(suffix, paired, connected) {
   objects["/org/bluez/hci0/dev_" + suffix] = {"org.bluez.Device1": {
    Address: {data: "AA:BB:CC:DD:EE:" + suffix}, Alias: {data: "Device " + suffix},
    Paired: {data: paired}, Connected: {data: connected}
   }}
  }
  add("01", false, true)
  add("02", true, false)
  add("03", false, false)
  add("04", true, true)
  BluetoothService._applyManagedObjects(JSON.stringify({data: [objects]}))
  const rows = BluetoothService.devices
  const connectedUnpaired = rows.find(d => d.mac.endsWith("01"))
  const ok = rows.length === 3 && connectedUnpaired && connectedUnpaired.connected
   && rows[0].connected && rows[1].connected && !rows[2].connected
   && BluetoothService.discovered.length === 1
   && BluetoothService.discovered[0].mac.endsWith("03")
  console.log(ok ? "BLUETOOTH DEVICES PASS" : "FAIL device visibility")
  Qt.callLater(() => Qt.quit())
 }
}
''')
    result = subprocess.run(
        ["quickshell", "-p", str(stage)],
        env=dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=8,
    )
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "BLUETOOTH DEVICES PASS" in output and "FAIL " not in output
