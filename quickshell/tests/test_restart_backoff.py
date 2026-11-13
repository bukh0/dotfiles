"""Restart delays begin at 250 ms, increase to the cap and skip intentional stops."""
from pathlib import Path
import subprocess

source = (Path(__file__).resolve().parents[1] / 'components/SysmonService.qml').read_text()
a = source.index('    function _scheduleRestart()')
z = source.index('\n    Timer {', a)
script = '''const assert = require('node:assert/strict');
const root = {watchers: 1, _restartDelay: 250, _stoppingForIdle: false, _restartForTemperature: false};
const startupCheck = {stop() {}}, sysmonStableTimer = {stop() {}};
const delays = [];
const sysmonRestart = {running: false, interval: 0, restart() { delays.push(this.interval) }};
''' + source[a:z] + '''
for (let i = 0; i < 10; i++) _scheduleRestart();
assert.deepEqual(delays, [250, 500, 1000, 2000, 4000, 8000, 16000, 30000, 30000, 30000]);
root._restartDelay = 250;
root._restartForTemperature = true;
_scheduleRestart();
assert.equal(root._restartDelay, 250);
root.watchers = 0;
const count = delays.length;
_scheduleRestart();
assert.equal(delays.length, count);
console.log('PASS restart backoff');
'''
subprocess.run(['node', '-e', script], check=True, timeout=5)
