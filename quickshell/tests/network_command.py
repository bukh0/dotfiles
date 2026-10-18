"""Commands settle after stderr, including failed spawns and reentrant requests."""
from pathlib import Path
import os
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'components/NetworkService.qml').read_text()
process = source[source.index('    Process {\n        id: cmdProc'):source.index('    function clearStatus()')]
run = source[source.index('    function runCommand('):source.index('    Process {\n        id: statusPoll')]
for delayed in [False, True]:
    fixture = process
    if delayed:
        fixture = fixture.replace('cmdProc._stderrDone = true\n                commandSettled.restart()', 'delayedStream.restart()', 1)
        fixture += '''
 Timer {
  id: delayedStream; interval: 150
  onTriggered: {
   if (!root.busy) { console.log("FAIL settled before collector"); Qt.quit(); return }
   cmdProc._stderrDone = true
   commandSettled.restart()
  }
 }
'''
    with tempfile.TemporaryDirectory(prefix='qs-network-command-') as directory:
        stage = Path(directory)
        (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
 Item {
  id: root
  property string actionKind: ""
  property string targetSsid: ""
  readonly property bool busy: actionKind !== ""
  property var errors: []
  property int settled: 0
  signal commandError(string message)
  signal connectionSettled()
  onCommandError: message => { errors = errors.concat([message]) }
  function reportStderr(text) { if (text.length) commandError(text) }
  function refresh() {}
  function _drainMonitor() {}
''' + fixture + run + '''
  Component.onCompleted: runCommand(["sh", "-c", "printf 'first stderr' >&2; sleep 0.1; exit 1"], "first")
  onConnectionSettled: {
   settled++
   if (settled === 1) runCommand(["/nonexistent/qs-network-command-test"], "missing")
   else if (settled === 2) runCommand(["sh", "-c", "printf 'last stderr' >&2; exit 1"], "last")
   else done.restart()
  }
  Timer {
   id: done; interval: 150
   onTriggered: {
    const expected = ["first stderr", "Could not start network command", "last stderr"]
    if (root.busy || root.settled !== 3 || root.targetSsid !== "" || JSON.stringify(root.errors) !== JSON.stringify(expected))
     console.log("FAIL settlement", root.settled, JSON.stringify(root.errors))
    else console.log("NETWORK COMMAND PASS")
    Qt.quit()
   }
  }
 }
 Timer { interval: 4000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
''')
        result = subprocess.run(['quickshell', '-p', directory], env=dict(os.environ,
            QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory), capture_output=True, text=True, timeout=7)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and 'NETWORK COMMAND PASS' in output and 'FAIL ' not in output
