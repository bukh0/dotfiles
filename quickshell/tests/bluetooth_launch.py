"""Exercise Bluetooth action spawn failure after success, with real collectors."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'components/BluetoothService.qml').read_text()
action = source[source.index('    Process {\n        id: actionProc'):source.index('    function _validMac(')]
action = action.replace('        actionProc.running = true', '        if (root.failSpawn) actionProc.command = ["/nonexistent/qs-bt-test"]\n        actionProc.running = true')
# Delay delivery of the stream completion event beyond the old 40 ms grace
# period, while retaining the real process and collector.
if os.environ.get("QS_TEST_DELAY_STREAM") == "1":
    action = action.replace(
        "actionProc._streamDone = true\n                if (actionProc._exited) root._finishAction()",
        "delayedStream.restart()")
    action += """
    Timer {
        id: delayedStream
        interval: 150
        onTriggered: {
            if (!root.busy) { console.log("FAIL finalized before stream completion"); Qt.quit(); return }
            actionProc._streamDone = true
            if (actionProc._exited) root._finishAction()
        }
    }
"""
helper = source[source.index('    function _stripAnsi('):source.index('    // ── State polling')]
with tempfile.TemporaryDirectory(prefix='qs-bluetooth-launch-') as directory:
    stage = Path(directory)
    (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
 Item {
  id: root
  property bool busy: false
  property string actionKind: ""
  property string targetMac: ""
  property bool failSpawn: false
  property var notices: []
  function notify(title, body) { notices = notices.concat([body]) }
  function refresh() {}
''' + helper + action + '''
  Timer {
   interval: 20; running: true; repeat: true
   property int phase: 0
   onTriggered: {
    if (root.busy) return
    if (phase === 0) {
     root._startAction("connect", "", "printf 'fresh output'", [])
     phase = 1
    } else if (phase === 1) {
     if (root.notices.length) { console.log("FAIL unexpected first-action warning"); Qt.quit(); return }
     root.failSpawn = true
     root._startAction("connect", "", "true", [])
     phase = 2
    } else {
     console.log(root.notices.length === 1 && root.notices[0] === "Command failed to run"
                 ? "BLUETOOTH LAUNCH PASS" : "FAIL stale action result: " + JSON.stringify(root.notices))
     Qt.quit()
    }
   }
  }
 }
 Timer { interval: 5000; running: true; onTriggered: { console.log("FAIL timed out"); Qt.quit() } }
}
''')
    result = subprocess.run(['quickshell', '-p', str(stage)], env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory), capture_output=True, text=True, timeout=8)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and 'BLUETOOTH LAUNCH PASS' in output and 'FAIL ' not in output
