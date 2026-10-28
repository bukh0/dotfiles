"""Profile connections remain visible when BlueZ's Device1 flag is false."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="qs-bt-profiles-") as directory:
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
  const n = BluetoothService
  const path = "/org/bluez/hci0/dev_00_00_00_00_03_80"
  const device = {"org.bluez.Device1": {
   Address: {data:"00:00:00:00:03:80"}, Alias: {data:"Pebble"},
   Paired: {data:true}, Connected: {data:false}
  }}
  const objects = {"/org/bluez/hci0": {"org.bluez.Adapter1": {Powered:{data:true}}}}
  objects[path] = device
  function check(expected, label) {
   // Suppress desktop notifications; exercise only state derivation.
   n._prevConnected = null
   n._applyManagedObjects(JSON.stringify({data:[objects]}))
   if (n.devices.length !== 1 || n.devices[0].connected !== expected
       || n.connectedName !== (expected ? "Pebble" : ""))
    throw new Error(label)
  }
  try {
   check(false, "paired alone")
   device["org.bluez.MediaControl1"] = {Connected:{data:true}}
   check(true, "media profile connected")
   delete device["org.bluez.MediaControl1"]
   const transport = {Device:{data:path}, State:{data:"active"}}
   objects[path + "/sep1/fd0"] = {"org.bluez.MediaTransport1":transport}
   check(true, "active audio with Device1 disconnected")
   transport.State.data = "pending"
   check(true, "pending audio")
   transport.State.data = "idle"
   check(false, "idle transport alone")
   transport.State.data = "active"
   transport.Device.data = "/org/bluez/hci0/another_device"
   check(false, "another device transport")
   delete objects[path + "/sep1/fd0"]
   check(false, "transport removed")
   device["org.bluez.Network1"] = {Connected:{data:true}}
   check(true, "network profile connected")
   delete device["org.bluez.Network1"]
   device["org.bluez.Device1"].Connected.data = true
   check(true, "normal Device1 connection")
   console.log("BLUETOOTH PROFILES PASS")
  } catch (e) { console.error("BLUETOOTH PROFILES FAIL", e) }
  Qt.callLater(() => Qt.quit())
 }
}
''')
    result = subprocess.run(
        ["quickshell", "-p", str(stage)],
        env=dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=10,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "BLUETOOTH PROFILES PASS" in output and "BLUETOOTH PROFILES FAIL" not in output, output
    print("PASS Bluetooth profile connections, transport ownership, and disconnection")
