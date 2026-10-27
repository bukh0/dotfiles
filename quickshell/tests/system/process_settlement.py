"""Exercise exit/stream reordering without relying on scheduler timing."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qs-settlement-') as directory:
    p = Path(directory)
    network = (ROOT/'components/NetworkService.qml').read_text()
    network = network.replace('id: root', 'id: root\n property alias poll: statusPoll', 1)
    network = network.replace('running: true', 'running: false').replace('Component.onCompleted: root.refresh()', 'Component.onCompleted: {}')
    brightness = (ROOT/'components/BrightnessService.qml').read_text()
    brightness = brightness.replace('id: root', 'id: root\n property alias writer: setProc\n property string reported: ""', 1)
    brightness = brightness.replace('running: !root.available', 'running: false')
    brightness = brightness.replace('function _reportError(msg) {', 'function _reportError(msg) {\n reported = msg; return\n')
    (p/'NetworkService.qml').write_text(network)
    (p/'BrightnessService.qml').write_text(brightness)
    (p/'qmldir').write_text('singleton NetworkService 1.0 NetworkService.qml\nsingleton BrightnessService 1.0 BrightnessService.qml\n')
    (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 function check(ok, message) { if (!ok) throw new Error(message) }
 Component.onCompleted: {
  try {
   const n = NetworkService, b = BrightnessService
   n.wifiOn = true
   n.networks = [{ssid: "keep"}]
   n.awaitingPasswordFor = "keep"
   for (let exitFirst of [false, true]) {
    n._statusInFlight = true
    n.poll.started = true
    n.poll.succeeded = false
    n.poll.output = "disabled\\n"
    n.poll.exited = exitFirst
    n.poll.stdoutDone = !exitFirst
    n.finishStatus()
    check(n._statusInFlight && n.wifiOn, "premature network settlement")
    n.poll.exited = true; n.poll.stdoutDone = true
    n.finishStatus()
    check(!n._statusInFlight && n.wifiOn && n.awaitingPasswordFor === "keep", "failed poll applied stdout")
   }
   n._statusInFlight = true; n.poll.succeeded = true; n.finishStatus()
   check(!n.wifiOn && n.awaitingPasswordFor === "", "successful radio update ignored")
   for (let exitFirst of [false, true]) {
    b._writeFinished = false; b._writeStarted = true
    b.writer.exited = exitFirst; b.writer.stderrDone = !exitFirst
    b.writer.succeeded = false; b.writer.exitCode = 1
    b.writer.errorText = "Permission denied"; b.reported = ""
    b._finishWrite()
    check(!b._writeFinished && b.reported === "", "premature brightness settlement")
    b.writer.exited = true; b.writer.stderrDone = true
    b._finishWrite()
    check(b._writeFinished && b.reported === "Permission denied", "stderr lost to generic error")
   }
   // No process signals: the launch watchdog must release the write.
   b._writeFinished = true; b.available = true; b.maxRaw = 100
   b.device = "mock"; b._wantedRaw = 50
   b._flush()
  } catch (e) { console.log("SETTLEMENT FAIL", e); Qt.quit() }
 }
 Timer { interval: 800; running: true; onTriggered: {
  console.log(BrightnessService._writeFinished && BrightnessService.reported === "Could not start brightnessctl."
              ? "SETTLEMENT PASS" : "SETTLEMENT FAIL watchdog")
  Qt.quit()
 } }
}
''')
    # Force spawn failure and suppress the failed-spawn runningChanged callback.
    brightness = brightness.replace('["brightnessctl", "-q",', '["/nonexistent/brightnessctl", "-q",')
    brightness = brightness.replace('onRunningChanged: if (!running) writeSettled.restart()', 'onRunningChanged: {}')
    (p/'BrightnessService.qml').write_text(brightness)
    result = subprocess.run(['quickshell', '-p', directory], capture_output=True, text=True,
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory), timeout=5)
    output = result.stdout + result.stderr
    assert 'SETTLEMENT PASS' in output and 'SETTLEMENT FAIL' not in output, output
    print('PASS exit/stream ordering, failed status preservation, stderr precedence and missing spawn signals')
