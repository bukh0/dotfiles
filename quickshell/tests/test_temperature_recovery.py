"""A disappeared sensor is rediscovered while resource sampling continues."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qs-temperature-') as directory:
    stage = Path(directory)
    shutil.copy(root / 'components/ManagedProcess.qml', stage)
    source = (root / 'components/SysmonService.qml').read_text()
    start = source.index('        command: ["sh", "-c",', source.index('id: tempSourceDiscover'))
    end = source.index('        Component.onCompleted:', start)
    source = source[:start] + '        command: ["sh", "-c", "cat \\"$QS_TEST_SENSOR\\""]\n' + source[end:]
    (stage / 'SysmonService.qml').write_text(source)
    sensor = stage / 'sensor'
    sensor.write_text('/old/sensor\n')
    helper = stage / 'sysmon'
    helper.write_text('''#!/usr/bin/env python3
import os, sys, time
from pathlib import Path
path = sys.argv[1]
with open(os.environ['QS_TEST_STARTS'], 'a') as f: f.write(path + '\\n')
if path == '/old/sensor': Path(os.environ['QS_TEST_SENSOR']).write_text('/new/sensor\\n')
while True:
 print('\\x1f'.join(['0%', '', '0%', '', '', '', '', 'N/A' if path == '/old/sensor' else '42°C', '0', '', 'auto']), flush=True)
 time.sleep(.1)
''')
    helper.chmod(0o755)
    (stage / 'Theme.qml').write_text('pragma Singleton\nimport QtQml\nQtObject { property string sysmonPath: "' + str(helper) + '" }\n')
    (stage / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton SysmonService 1.0 SysmonService.qml\nManagedProcess 1.0 ManagedProcess.qml\n')
    (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Component.onCompleted: SysmonService.watchers = 1
 Timer { interval: 1800; running: true; onTriggered: {
  if (SysmonService.tempSourcePath !== "/new/sensor" || SysmonService.cpuTemp !== "42°C" || !SysmonService.sampling)
   throw new Error("Sensor did not recover while sampling")
  if (SysmonService._temperatureFailures !== 0 || SysmonService._temperatureRetrySamples !== 3)
   throw new Error("Successful sample did not reset retries")
  SysmonService.watchers = 0
  console.log("TEMPERATURE PASS"); Qt.quit()
 } }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory,
               QS_TEST_SENSOR=str(sensor), QS_TEST_STARTS=str(stage / 'starts'))
    env.pop('WAYLAND_DISPLAY', None)
    try:
        result = subprocess.run(['quickshell', '-p', directory], env=env, capture_output=True, text=True, timeout=8)
    except subprocess.TimeoutExpired as error:
        raise AssertionError((error.stdout or b" ").decode() + (error.stderr or b" ").decode()) from error
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'TEMPERATURE PASS' in output, output
    assert 'Error:' not in output, output
    assert (stage / 'starts').read_text().splitlines() == ['/old/sensor', '/new/sensor']
print('PASS sensor relocation and sampling restart')
