"""Real QProcess lifecycle: output draining, reuse, spawn failure and cancellation."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-process-') as directory:
    stage = Path(directory)
    shutil.copy(root / 'components/ManagedProcess.qml', stage)
    (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
 property int step: 0
 property int completions: 0
 function require(ok, message) { if (!ok) throw new Error(message) }
 function launch() {
  const commands = [
   ["sh", "-c", "printf first; printf warning >&2; exit 7"],
   ["/nonexistent/qs-test-command"],
   ["sh", "-c", "exec 1>&- 2>&-; sleep 0.1"],
   ["python3", "-c", "import sys; sys.stdout.write(100000 * chr(120)); sys.stderr.write(100000 * chr(121))"],
   ["sh", "-c", "kill -KILL $$"],
   ["sleep", "10"],
   ["sh", "-c", "printf final"]
  ]
  require(job.start(commands[step]), "Could not reuse job")
  require(!job.start(["sh", "-c", "exit 99"]), "Accepted overlapping job")
  if (step === 5) cancelTimer.start()
 }
 ManagedProcess {
  id: job
  onCompleted: result => {
   require(!pending && !running, "Completion before settlement")
   completions++
   if (step === 0) require(result.started && !result.success && result.exitCode === 7 && result.stdout === "first" && result.stderr === "warning", "Lost failed-job output")
   if (step === 1) require(!result.started && !result.success && result.stdout === "" && result.stderr === "", "Stale output after spawn failure")
   if (step === 2) require(result.success && result.stdout === "" && result.stderr === "", "Early EOF failed")
   if (step === 3) require(result.success && result.stdout === "x".repeat(100000) && result.stderr === "y".repeat(100000), "Output not drained")
   if (step === 4) require(!result.success && result.exitStatus !== 0, "Crash reported success")
   if (step === 5) require(result.cancelled && !result.success, "Cancellation reported success")
   if (step === 6) { require(result.success && result.stdout === "final", "Reuse after cancellation failed"); done.start(); return }
   step++
   launch()
  }
 }
 Timer { id: cancelTimer; interval: 100; onTriggered: job.cancel() }
 Timer { id: done; interval: 100; onTriggered: {
  require(completions === 7, "Duplicate completion")
  console.log("PROCESS PASS"); Qt.quit()
 } }
 Component.onCompleted: launch()
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory)
    env.pop('WAYLAND_DISPLAY', None)
    try:
        result = subprocess.run(['quickshell', '-p', directory], env=env, capture_output=True, text=True, timeout=12)
    except subprocess.TimeoutExpired as error:
        raise AssertionError((error.stdout or b" ").decode() + (error.stderr or b" ").decode()) from error
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PROCESS PASS' in output, output
    assert not any(s in output for s in ('Error:', 'Binding loop', 'Failed to load')), output
print('PASS process lifecycle and immediate reuse')
