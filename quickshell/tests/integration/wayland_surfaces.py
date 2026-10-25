"""Opt-in live Wayland checks: briefly shows a tooltip and pins a test panel."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
if os.environ.get('QS_SURFACE_TEST_BUS') != '1':
    with tempfile.TemporaryDirectory(prefix='qs-surface-bus-') as directory:
        config = Path(directory) / 'bus.conf'
        config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=' + directory +
            '</listen><policy context="default"><allow send_destination="*"/>'
            '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        raise SystemExit(subprocess.run(['dbus-run-session', '--config-file', str(config),
            '--', sys.executable, __file__], env=dict(os.environ, QS_SURFACE_TEST_BUS='1')).returncode)

for scenario in ['tooltip', 'focus']:
    with tempfile.TemporaryDirectory(prefix='qs-surface-test-') as directory:
        root = Path(directory)
        (root / 'profile').symlink_to(ROOT / 'profiles/default', target_is_directory=True)
        content = '''
 PanelWindow {
  implicitWidth: 300; implicitHeight: 42
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "qs-tooltip-test"
  Config.NetworkIndicator { id: network; x:140; y:12 }
 }
 Timer { interval: 150; running:true; onTriggered: {
  const tip = network.resources.find(item => item.objectName === "networkTooltip")
  if (!tip) { console.error("FAIL missing tooltip"); Qt.quit(); return }
  tip.delay=0
  tip.visible=true
 } }
''' if scenario == 'tooltip' else '''
 Config.ControlPanel { id: panel; isOpen:true; pinned:false }
 Timer { interval: 250; running:true; onTriggered: panel.pinned=true }
'''
        (root / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Wayland
import "profile" as Config
ShellRoot {
''' + content + '''
 Timer { interval: 900; running:true; onTriggered: Qt.quit() }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM='wayland', XDG_RUNTIME_DIR=directory,
                   XDG_CACHE_HOME=directory, WAYLAND_DEBUG='1',
                   WAYLAND_DISPLAY=str(Path(os.environ['XDG_RUNTIME_DIR']) / os.environ['WAYLAND_DISPLAY']))
        env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        result = subprocess.run(['quickshell', '-p', directory], env=env,
            capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and not any(error in output for error in
            ['FAIL ', 'Failed to load configuration', 'ReferenceError', 'TypeError']), output
        if scenario == 'tooltip':
            assert re.search(r'get_popup\(', output), output
            assert re.search(r'xdg_popup#\d+\.configure\(', output), output
            print('PASS actual network tooltip receives a separate Wayland popup surface')
        else:
            assert re.search(r'set_keyboard_interactivity\(0\)', output), output
            assert re.search(r'set_keyboard_interactivity\(1\)', output), output
            assert re.search(r'wl_keyboard#\d+\.enter\(', output), output
            print('PASS actual panel receives keyboard focus after hover-to-pin transition')
