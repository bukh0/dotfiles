"""Exercise status/scan ordering and monitor coalescing without hardware."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="qs-status-refresh-") as directory:
    stage = Path(directory)
    for name in ("NetworkService", "BluetoothService"):
        source = (ROOT / "components" / (name + ".qml")).read_text()
        source = source.replace("running: true", "running: false")
        source = source.replace("Component.onCompleted: root.refresh()", "Component.onCompleted: {}")
        if name == "NetworkService":
            source = source.replace("id: root", '''id: root
 function testStatus(s) { statusPoll.output = s; applyStatus() }
 function testScan(s) {
  scanPoll.output = s; scanPoll.exited = true; scanPoll.stdoutDone = true
  scanPoll.succeeded = true; scanSettled.triggered()
 }
''', 1)
        else:
            source = source.replace("onTriggered: root.refresh()", "onTriggered: root.testPolls++")
            source = source.replace("id: root", "id: root\n property int testPolls: 0", 1)
        (stage / (name + ".qml")).write_text(source)
    (stage / "qmldir").write_text("singleton NetworkService 1.0 NetworkService.qml\nsingleton BluetoothService 1.0 BluetoothService.qml\n")
    (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 property int changes: 0
 property bool failed: false
 Connections { target: NetworkService; function onConnectionChanged() { changes++ } }
 function check(ok, label) { if (!ok) { failed = true; console.error("FAIL", label) } }
 Component.onCompleted: {
  const n = NetworkService
  const status = "enabled\\nyes:Home:80:wlan0\\nwifi:connected:wlan0"
  const stale = "Home:80:WPA2:no:wlan0"
  n.testStatus(status)
  n.testScan(stale)
  check(!n.networks[0].active, "stale scan setup")
  n.testStatus(status)
  check(n.networks[0].active && n.networks[0].activeDevices[0] === "wlan0", "repair unchanged status")
  check(changes === 1, "no redundant connection event")
  const rows = n.networks
  n.testScan("Home:80:WPA2:yes:wlan0")
  check(n.networks === rows, "identical scan preserves delegates")
  n.clearStatus()
  n.testScan(stale)
  n.testStatus(status)
  check(changes === 2 && n.networks[0].active, "recover same connection")
  n.testStatus("enabled\\nwifi:disconnected:wlan0")
  check(!n.networks[0].active && n.networks[0].activeDevices.length === 0, "disconnect")
  BluetoothService.handleMonitorLine('   string "My State Headphones"')
 }
 Timer { interval: 350; running: true
  onTriggered: {
   check(BluetoothService.testPolls === 0, "ignore property values containing State")
   burst.start()
   deadline.start()
  }
 }
 Timer { id: burst; interval: 20; repeat: true
  onTriggered: BluetoothService.handleMonitorLine('   string "Connected"')
 }
 Timer { id: deadline; interval: 500
  onTriggered: {
   burst.stop()
   check(BluetoothService.testPolls === 1, "continuous events refresh within 300ms window")
   if (!failed) console.log("STATUS REFRESH PASS")
   Qt.quit()
  }
 }
}
''')
    result = subprocess.run(
        ["quickshell", "-p", str(stage)],
        env=dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory),
        capture_output=True, text=True, timeout=10,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "STATUS REFRESH PASS" in output and "FAIL" not in output, output
    print("PASS status recovery, stale scans, unchanged models, and bounded Bluetooth refreshes")
