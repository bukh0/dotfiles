import importlib.util
from pathlib import Path
from types import SimpleNamespace
from unittest import mock
root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('control', root / 'native/bluetooth_control.py')
helper = importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)
objects = {
 '/org/bluez/hci0': {'org.bluez.Adapter1': {'Powered': True}},
 '/org/bluez/hci1': {'org.bluez.Adapter1': {'Powered': True}},
 '/org/bluez/hci0/dev_AA': {'org.bluez.Device1': {'Address': 'AA:BB:CC:DD:EE:FF'}},
 '/org/bluez/hci1/dev_AA': {'org.bluez.Device1': {'Address': 'AA:BB:CC:DD:EE:FF'}},
}
calls = []
class Bus:
 def call_sync(self, destination, path, interface, method, parameters, *args):
  calls.append((path, interface, method, parameters))
  return SimpleNamespace(unpack=lambda: (objects,))
class Error(Exception): pass
Gio = SimpleNamespace(bus_get_sync=lambda *a: Bus(), BusType=SimpleNamespace(SYSTEM=0), DBusCallFlags=SimpleNamespace(NONE=0))
GLib = SimpleNamespace(Variant=lambda signature, value: value, Error=Error)
with mock.patch.dict('sys.modules', {'gi.repository': SimpleNamespace(Gio=Gio, GLib=GLib)}):
 helper.main('disconnect', '/org/bluez/hci1/dev_AA')
 assert calls[-1][:3] == ('/org/bluez/hci1/dev_AA', 'org.bluez.Device1', 'Disconnect')
 calls.clear()
 helper.main('power', 'off')
 changes = [c for c in calls if c[2] == 'Set']
 assert [c[0] for c in changes] == ['/org/bluez/hci0', '/org/bluez/hci1']
 assert all(c[3] == ('org.bluez.Adapter1', 'Powered', False) for c in changes)
 try:
  helper.main('connect', '/org/bluez/hci2/dev_AA')
  raise AssertionError('Missing device accepted')
 except RuntimeError: pass
calls.clear()
GLib.MainLoop = mock.Mock
GLib.timeout_add_seconds = mock.Mock()
GLib.unix_signal_add = mock.Mock()
GLib.PRIORITY_DEFAULT = 0
GLib.SOURCE_REMOVE = False
with mock.patch.dict('sys.modules', {'gi.repository': SimpleNamespace(Gio=Gio, GLib=GLib)}):
 helper.main('scan', '1')
 assert [(c[0], c[2]) for c in calls if c[2] in ('StartDiscovery', 'StopDiscovery')] == [
  ('/org/bluez/hci0', 'StartDiscovery'), ('/org/bluez/hci1', 'StartDiscovery'),
  ('/org/bluez/hci0', 'StopDiscovery'), ('/org/bluez/hci1', 'StopDiscovery')]
print('PASS actions target the selected adapter and power applies to all adapters')

# One adapter failing must not cancel discovery on healthy adapters.
class PartialBus(Bus):
 def call_sync(self, destination, path, interface, method, parameters, *args):
  result = super().call_sync(destination, path, interface, method, parameters, *args)
  if method == 'StartDiscovery' and path.endswith('hci1'):
   raise Error('adapter unavailable')
  return result
calls.clear()
loop = mock.Mock()
GLib.MainLoop = lambda: loop
Gio.bus_get_sync = lambda *a: PartialBus()
with mock.patch.dict('sys.modules', {'gi.repository': SimpleNamespace(Gio=Gio, GLib=GLib)}):
 with mock.patch('sys.stderr') as stderr:
  helper.main('scan', '1')
  assert 'adapter unavailable' in ''.join(c.args[0] for c in stderr.write.call_args_list)
 loop.run.assert_called_once()
 assert [(c[0], c[2]) for c in calls if c[2] == 'StopDiscovery'] == [('/org/bluez/hci0', 'StopDiscovery')]
class FailedBus(Bus):
 def call_sync(self, destination, path, interface, method, parameters, *args):
  if method == 'StartDiscovery': raise Error('all unavailable')
  return super().call_sync(destination, path, interface, method, parameters, *args)
Gio.bus_get_sync = lambda *a: FailedBus()
with mock.patch.dict('sys.modules', {'gi.repository': SimpleNamespace(Gio=Gio, GLib=GLib)}):
 try:
  helper.main('scan', '1')
  raise AssertionError('All-adapter failure reported success')
 except RuntimeError as error:
  assert 'all unavailable' in str(error)
print('PASS partial and total discovery failures')
