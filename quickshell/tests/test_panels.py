"""Exercise full panel composition and focus handoff using offscreen window adapters."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
for profile in ('default', 'alt'):
    with tempfile.TemporaryDirectory(prefix='qs-panels-') as directory:
        stage = Path(directory) / 'profile'
        shutil.copytree(root / 'profiles' / profile, stage, symlinks=False)
        for file in stage.glob('*.qml'):
            text = file.read_text().replace('PanelWindow {', 'TestPanelWindow {')
            text = re.sub(r'^\s*WlrLayershell\.[^\n]*\n', '\n', text, flags=re.M)
            text = re.sub(r'anchors\s*\{(?:\s*(?:top|bottom|left|right):\s*true\s*;?)+\s*\}', '', text)
            text = re.sub(r'margins \{ top: content.barHeight[^}]*\}', '', text)
            file.write_text(text)
        (stage / 'TestPanelWindow.qml').write_text('''import QtQuick
import Quickshell
FloatingWindow {
 property int exclusionMode: 0
 property QtObject anchors: QtObject { property bool top; property bool bottom; property bool left; property bool right }
 property QtObject margins: QtObject { property int top; property int bottom; property int left; property int right }
 implicitWidth: 1000; implicitHeight: 850
}
''')
        with (stage / 'qmldir').open('a') as f:
            f.write('\nTestPanelWindow 1.0 TestPanelWindow.qml\n')
        (stage / 'shell.qml').write_text('''//@ pragma UseQApplication
import QtQuick
import Quickshell
import "."
ShellRoot {
 Bar { id: bar; screen: Quickshell.screens[0] }
 ControlPanel { id: panel; screen: Quickshell.screens[0]; outputName: "test"; isOpen: true; pinned: true }
 NotificationDrawer { screen: Quickshell.screens[0] }
 NotificationPopup { screen: Quickshell.screens[0] }
 Timer { interval: 1000; running: true; onTriggered: {
  BluetoothService._applyManagedObjects(JSON.stringify({data: [{
   "/org/bluez/hci0": {"org.bluez.Adapter1": {Powered: {data: true}}},
   "/org/bluez/hci1": {"org.bluez.Adapter1": {Powered: {data: true}}},
   "/org/bluez/hci0/dev_AA": {"org.bluez.Device1": {Address: {data: "AA:BB:CC:DD:EE:FF"}, Alias: {data: "Headset"}, Paired: {data: true}}},
   "/org/bluez/hci1/dev_AA": {"org.bluez.Device1": {Address: {data: "AA:BB:CC:DD:EE:FF"}, Alias: {data: "Headset"}, Paired: {data: true}}}
  }]}))
  if (BluetoothService.devices.length !== 2 || BluetoothService.devices[0].path === BluetoothService.devices[1].path) throw new Error("Lost adapter ownership")
  BluetoothService.externalDialogRequested()
  if (panel.isOpen || panel.pinned) throw new Error("Bluetooth dialog retained panel focus")
  panel.pinned = true; panel.isOpen = true
  SysmonService.externalDialogRequested()
  if (panel.isOpen || panel.pinned) throw new Error("Authentication retained panel focus")
  console.log("PANELS PASS")
  Qt.quit()
 } }
}
''')
        bindir = Path(directory) / 'bin'; bindir.mkdir()
        for name, contents in {
            'nmcli': 'case "$1" in monitor) sleep 5;; radio) echo disabled;; esac',
            'busctl': 'printf \'{"data":[{}]}\\n\'',
            'dbus-monitor': 'sleep 5',
            'brightnessctl': 'exit 1',
            'notify-send': 'exit 0',
        }.items():
            file = bindir / name; file.write_text('#!/bin/sh\n' + contents + '\n'); file.chmod(0o755)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   XDG_RUNTIME_DIR=directory, XDG_CACHE_HOME=directory,
                   PATH=str(bindir) + os.pathsep + os.environ['PATH'],
                   DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
        env.pop('WAYLAND_DISPLAY', None)
        result = subprocess.run(['quickshell', '-p', str(stage)], env=env, capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'PANELS PASS' in output, output
        assert not any(s in output for s in ('ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', 'Cannot assign', 'Failed to load', 'QColor::setAlphaF')), output
        print('PASS', profile)
