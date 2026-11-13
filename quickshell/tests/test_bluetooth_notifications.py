"""Run the real object parser against duplicate adapter records and transitions."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
s = (root/'components/BluetoothService.qml').read_text()
a = s.index('    function _applyManagedObjects(')
z = s.index('\n    ManagedProcess {', a)
script = '''const assert = require('node:assert/strict');
const events = [];
const root = {
 _prevConnected: [], _prevNames: {}, maxDiscovered: 8,
 _assign(key, value) { this[key] = value },
 _markUnavailable() { throw new Error('Invalid fixture') },
 notify(title, body) { events.push([title, body]) }
};
'''+s[a:z]+'''
const objects = {};
for (const adapter of ['hci0', 'hci1']) {
 objects['/org/bluez/'+adapter] = {'org.bluez.Adapter1': {Powered: {data: true}}};
 objects['/org/bluez/'+adapter+'/dev_AA'] = {'org.bluez.Device1': {
  Address: {data: 'AA:BB:CC:DD:EE:FF'}, Alias: {data: 'Headset'},
  Paired: {data: true}, Connected: {data: true}
 }};
}
function apply() { _applyManagedObjects(JSON.stringify({data: [objects]})) }
apply(); apply();
assert.equal(root.devices.length, 2);
assert.notEqual(root.devices[0].path, root.devices[1].path);
assert.equal(root.connectedName, 'Headset');
assert.deepEqual(events, [['Bluetooth Connected', 'Headset']]);
objects['/org/bluez/hci0/dev_AA']['org.bluez.Device1'].Connected.data = false;
apply();
assert.equal(events.length, 1);
objects['/org/bluez/hci1/dev_AA']['org.bluez.Device1'].Connected.data = false;
apply(); apply();
assert.equal(root.connectedName, '');
assert.deepEqual(events, [['Bluetooth Connected', 'Headset'], ['Bluetooth Disconnected', 'Headset']]);
console.log('PASS deduplicated names and connection notifications, adapter rows retained');
'''
subprocess.run(['node', '-e', script], check=True, timeout=10)
