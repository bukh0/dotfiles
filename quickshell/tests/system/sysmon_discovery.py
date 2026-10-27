"""Unreadable temperature candidates must not mask usable sensors; prewarm while idle."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'components/SysmonService.qml').read_text()
match = re.search(r'command: \["sh", "-c",(.*?)\n        \]', source, re.S)
assert match
script = ''.join(json.loads(s) for s in re.findall(r'"(?:\\.|[^"\\])*"', match[1]))
assert 'SysmonService.initialize()' in (ROOT / 'components/shell.qml').read_text()
with tempfile.TemporaryDirectory(prefix='sysmon-discovery-') as directory:
    stage = Path(directory)
    thermal = stage / 'thermal'
    hwmon = stage / 'hwmon'
    def node(base, name, kind, sensor=None):
        p = base / name
        p.mkdir(parents=True)
        (p / ('type' if base == thermal else 'name')).write_text(kind)
        if sensor:
            (p / sensor).write_text('42000\n')
        return p
    node(thermal, 'thermal_zone0', 'x86_pkg_temp')
    node(hwmon, 'hwmon0', 'k10temp')
    good = node(hwmon, 'hwmon1', 'k10temp', 'temp1_input') / 'temp1_input'
    script = script.replace('/sys/class/thermal', str(thermal)).replace('/sys/class/hwmon', str(hwmon))
    def discover():
        return subprocess.check_output(['sh', '-c', script], text=True).strip()
    assert discover() == str(good), 'missing first sensors prevented fallback'
    for invalid in ('', 'N/A\n', '42000oops\n'):
        (thermal / 'thermal_zone0/temp').write_text(invalid)
        (hwmon / 'hwmon0/temp1_input').write_text(invalid)
        assert discover() == str(good), 'invalid numeric sensor prevented fallback'
    # A directory passes -r but cannot be read as a sensor value.
    (thermal / 'thermal_zone0/temp').unlink()
    (thermal / 'thermal_zone0/temp').mkdir()
    assert discover() == str(good)
    (thermal / 'thermal_zone0/temp').rmdir()
    (thermal / 'thermal_zone0/temp').write_text('-1000\n')
    assert discover() == str(thermal / 'thermal_zone0/temp')
    (thermal / 'thermal_zone0/temp').write_text('41000\n')
    assert discover() == str(thermal / 'thermal_zone0/temp')
    (thermal / 'thermal_zone0/temp').unlink()
    good.unlink()
    assert discover() == ''
    good.write_text('42000\n')
    assert discover() == str(good)
    print('PASS thermal/hwmon fallback, priority, missing sensors and recovery')

    # Execute the real singleton with mock sensor paths and a mock sampler.
    (stage / 'SysmonService.qml').write_text(source[:match.start()] + 'command: ["sh", "-c", '
        + json.dumps(script) + ']' + source[match.end():])
    sampler = stage / 'sampler'
    sampler.write_text('#!/bin/sh\necho "$1" >> "' + str(stage / 'launches') + '"\nexec sleep 10\n')
    sampler.chmod(0o755)
    (stage / 'Theme.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property string sysmonPath: ' + json.dumps(str(sampler)) + ' }\n')
    (stage / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton SysmonService 1.0 SysmonService.qml\n')
    (stage / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Component.onCompleted: SysmonService.initialize()
 Timer { interval: 600; running: true; onTriggered: {
  if (SysmonService.tempSourcePath !== ''' + json.dumps(str(good)) + ''' || SysmonService.sampling) {
   console.log("FAIL idle discovery"); Qt.quit(); return
  }
  SysmonService.watchers = 1
 } }
 Timer { interval: 1300; running: true; onTriggered: {
  console.log(SysmonService.sampling ? "PREWARM PASS" : "FAIL sampler did not start")
  SysmonService.watchers = 0
  Qt.quit()
 } }
}
''')
    result = subprocess.run(['quickshell', '-p', str(stage)], capture_output=True, text=True,
                            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory), timeout=5)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PREWARM PASS' in output and 'FAIL ' not in output, output
    assert (stage / 'launches').read_text().splitlines() == [str(good)]
    print('PASS discovery while idle and a single sampler launch on panel open')
