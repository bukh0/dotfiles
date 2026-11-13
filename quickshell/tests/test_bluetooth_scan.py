"""Scan errors reach the UI; intentional cancellation remains quiet."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
for mode in ('failure', 'partial', 'cancel', 'restart', 'restart_cancel'):
    with tempfile.TemporaryDirectory(prefix='qs-scan-') as directory:
        stage = Path(directory)
        shutil.copy(root / 'components/ManagedProcess.qml', stage)
        source = (root / 'components/BluetoothService.qml').read_text()
        source = source.replace('Quickshell.shellPath("../../native/bluetooth_control.py")', 'Quickshell.env("QS_SCAN_HELPER")')
        source = source.replace('Quickshell.execDetached(["notify-send", "-a", "Bluetooth", "--", title, body])', 'console.log("NOTICE", title, body)')
        (stage / 'BluetoothService.qml').write_text(source)
        (stage / 'qmldir').write_text('singleton BluetoothService 1.0 BluetoothService.qml\nManagedProcess 1.0 ManagedProcess.qml\n')
        helper = stage / 'scan.py'
        helper.write_text('''import os, sys, time
from pathlib import Path
starts = Path(os.environ["QS_SCAN_STARTS"])
count = int(starts.read_text()) + 1 if starts.exists() else 1
starts.write_text(str(count))
mode = os.environ['QS_SCAN_MODE']
if mode in ('cancel', 'restart_cancel') or (mode == 'restart' and count == 1): time.sleep(10)
elif mode == 'restart': pass
else:
 print('adapter unavailable', file=sys.stderr)
 sys.exit(3 if mode == 'failure' else 0)
''')
        bindir = stage / 'bin'
        bindir.mkdir()
        for name, body in {
            'busctl': 'printf \'{"data":[{"/hci0":{"org.bluez.Adapter1":{"Powered":{"data":true}}}}]}\\n\'',
            'dbus-monitor': 'exec sleep 10',
        }.items():
            command = bindir / name
            command.write_text('#!/bin/sh\n' + body + '\n')
            command.chmod(0o755)
        (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Component.onCompleted: BluetoothService.refresh()
 Timer { interval: 200; running: true; onTriggered: {
  if (!BluetoothService.powered) throw new Error("Fixture not powered")
  BluetoothService.scan()
 } }
 Timer { interval: 350; running: true; onTriggered: {
  const mode = Quickshell.env("QS_SCAN_MODE")
  if (mode === "cancel") BluetoothService.stopScan()
  if (mode === "restart" || mode === "restart_cancel") {
   BluetoothService.stopScan()
   BluetoothService.scan()
   if (mode === "restart_cancel") BluetoothService.stopScan()
  }
 } }
 Timer { interval: 750; running: true; onTriggered: {
  if (BluetoothService.scanning) throw new Error("Scan stuck running")
  console.log("SCAN PASS"); Qt.quit()
 } }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory,
                   QS_SCAN_HELPER=str(helper), QS_SCAN_MODE=mode, QS_SCAN_STARTS=str(stage / "starts"),
                   PATH=str(bindir) + os.pathsep + os.environ['PATH'])
        env.pop('WAYLAND_DISPLAY', None)
        result = subprocess.run(['quickshell', '-p', directory], env=env, capture_output=True, text=True, timeout=6)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'SCAN PASS' in output and 'Error:' not in output, output
        if mode in ('cancel', 'restart', 'restart_cancel'):
            assert 'NOTICE' not in output, output
            assert (stage / 'starts').read_text() == ('2' if mode == 'restart' else '1'), output
        else:
            assert ('Bluetooth Scan Failed' if mode == 'failure' else 'Bluetooth Scan Warning') in output, output
            assert 'adapter unavailable' in output, output
print('PASS scan errors, partial warnings and cancellation')
