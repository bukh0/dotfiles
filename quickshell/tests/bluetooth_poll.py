"""Poll success, failed launch, queued refresh, nonzero exit and recovery."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-bt-poll-') as directory:
    stage = Path(directory)
    source = (ROOT / 'components/BluetoothService.qml').read_text()
    source = source.replace('running: true', 'running: false').replace('Component.onCompleted: root.refresh()', 'Component.onCompleted: {}')
    source = source.replace('    id: root', '    id: root\n    property var testCommand: []', 1)
    source = re.sub(r'command: \["busctl", "--system", "-j", "call", "org.bluez", "/",\s*"org.freedesktop.DBus.ObjectManager", "GetManagedObjects"\]', 'command: root.testCommand', source)
    (stage / 'BluetoothService.qml').write_text(source)
    (stage / 'qmldir').write_text('singleton BluetoothService 1.0 BluetoothService.qml\n')
    fixture = stage / 'poll'
    fixture.write_text('''#!/bin/sh
printf '%s\\n' '{"data":[{"/adapter":{"org.bluez.Adapter1":{"Powered":{"data":true}}}}]}'
exit "$1"
''')
    fixture.chmod(0o755)
    (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Timer {
  interval: 20; running: true; repeat: true
  property int phase: 0
  onTriggered: {
   const bt = BluetoothService
   if (bt._pollInFlight) return
   if (phase > 0) {
    const expected = phase === 1 || phase === 4
    if (bt.hasAdapter !== expected || bt.powered !== expected || bt._pollQueued) {
     console.log("FAIL poll phase", phase); Qt.quit(); return
    }
   }
   if (phase === 4) { console.log("BLUETOOTH POLL PASS"); Qt.quit(); return }
   bt.testCommand = phase === 1 ? ["/nonexistent/qs-bt-poll"] : ["FIXTURE", phase === 2 ? "1" : "0"]
   bt.refresh()
   if (phase === 1) bt.refresh()
   phase++
  }
 }
 Timer { interval: 8000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
'''.replace('FIXTURE', str(fixture)))
    result = subprocess.run(['quickshell', '-p', directory], capture_output=True, text=True,
                            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory), timeout=12)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and 'BLUETOOTH POLL PASS' in output and 'FAIL ' not in output
