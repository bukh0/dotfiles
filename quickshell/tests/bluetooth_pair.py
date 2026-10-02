#!/usr/bin/env python3
"""Private fake BlueZ; real Blueman agent with simulated dialog responses."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
if os.environ.get("QS_PAIR_TEST_BUS") != "1":
    raise SystemExit(subprocess.run(["dbus-run-session", "--", sys.executable, __file__],
        env=dict(os.environ, QS_PAIR_TEST_BUS="1")).returncode)

SERVER = r'''
import os
from pathlib import Path
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
              'RequestName', GLib.Variant('(su)', ('org.bluez', 0)), None, Gio.DBusCallFlags.NONE, 5000, None)
device = '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF'
props = {'Address': GLib.Variant('s','AA:BB:CC:DD:EE:FF'), 'Alias': GLib.Variant('s','Test keyboard'),
         'Adapter': GLib.Variant('o','/org/bluez/hci0'), 'Trusted': GLib.Variant('b',False)}
agent = None
def record(event):
 with open(os.environ['TEST_EVENTS'], 'a') as f: f.write(event+'\n')
def call(conn, sender, path, interface, method, args, invocation):
 global agent
 if method == 'GetManagedObjects':
  invocation.return_value(GLib.Variant('(a{oa{sa{sv}}})', ({
   '/org/bluez/hci0': {'org.bluez.Adapter1': {'Powered': GLib.Variant('b',True)}},
   device: {'org.bluez.Device1': props}},)))
 elif method == 'RegisterAgent':
  agent=(sender,args.unpack()[0]); record('register'); invocation.return_value(None)
 elif method == 'UnregisterAgent':
  record('unregister'); invocation.return_value(None)
 elif method == 'Pair':
  record('pair')
  def confirmed(c, result):
   try:
    c.call_finish(result); invocation.return_value(None)
   except GLib.Error:
    invocation.return_dbus_error('org.bluez.Error.AuthenticationRejected','User rejected pairing')
  conn.call(agent[0],agent[1],'org.bluez.Agent1','RequestConfirmation',
            GLib.Variant('(ou)',(device,123456)),None,Gio.DBusCallFlags.NONE,5000,None,confirmed)
 elif method == 'Connect':
  record('connect'); invocation.return_value(None)
 elif method == 'CancelPairing': invocation.return_value(None)
def set_prop(conn,sender,path,interface,name,value):
 props[name]=value; record('trusted'); return True
def register(path,xml):
 info=Gio.DBusNodeInfo.new_for_xml('<node>'+xml+'</node>').interfaces[0]
 bus.register_object(path,info,call,lambda c,s,p,i,n: props[n],set_prop)
register('/', '<interface name="org.freedesktop.DBus.ObjectManager"><method name="GetManagedObjects"><arg type="a{oa{sa{sv}}}" direction="out"/></method></interface>')
register('/org/bluez', '<interface name="org.bluez.AgentManager1"><method name="RegisterAgent"><arg type="o"/><arg type="s"/></method><method name="UnregisterAgent"><arg type="o"/></method></interface>')
register(device, '<interface name="org.bluez.Device1"><method name="Pair"/><method name="Connect"/><method name="CancelPairing"/><property name="Alias" type="s" access="read"/><property name="Address" type="s" access="read"/><property name="Adapter" type="o" access="read"/><property name="Trusted" type="b" access="readwrite"/></interface>')
Path(os.environ['TEST_READY']).touch()
GLib.MainLoop().run()
'''

CLIENT = r'''
import importlib.util, os, sys
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk
import blueman.gui.Notification as notification
# Only the dialog rendering is replaced; registration and callbacks are real.
Gtk.init_check=lambda: (True, [])
class Dialog:
 def __init__(self,*args,actions_cb=None,**kwargs): self.callback=actions_cb
 def show(self):
  if self.callback: self.callback(os.environ['TEST_RESPONSE'])
 def close(self): pass
notification._NotificationDialog=Dialog
spec=importlib.util.spec_from_file_location('pair_helper',sys.argv[1])
helper=importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)
raise SystemExit(helper.main('AA:BB:CC:DD:EE:FF'))
'''

with tempfile.TemporaryDirectory(prefix="qs-bluetooth-pair-") as directory:
    stage = Path(directory)
    (stage / "server.py").write_text(SERVER)
    (stage / "client.py").write_text(CLIENT)
    # Redirect the helper's SYSTEM bus to this test's private session bus.
    env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=os.environ["DBUS_SESSION_BUS_ADDRESS"],
               TEST_READY=str(stage / "ready"), TEST_EVENTS=str(stage / "events"))
    with (stage / "server.log").open("w") as log:
        server = subprocess.Popen([sys.executable, str(stage / "server.py")], env=env, stdout=log, stderr=log)
        try:
            for _ in range(100):
                if (stage / "ready").exists() or server.poll() is not None:
                    break
                time.sleep(.02)
            assert (stage / "ready").exists(), (stage / "server.log").read_text()
            for response in ("confirm", "deny"):
                (stage / "events").write_text("")
                result = subprocess.run([sys.executable, str(stage / "client.py"), str(ROOT / "native/bluetooth_pair.py")],
                                        env=dict(env, TEST_RESPONSE=response), capture_output=True, text=True, timeout=12)
                expected = ["register", "pair", "trusted", "connect", "unregister"] if response == "confirm" else ["register", "pair", "unregister"]
                assert result.returncode == (0 if response == "confirm" else 1), result.stdout + result.stderr
                assert (stage / "events").read_text().splitlines() == expected, result.stdout + result.stderr
            print("PASS Bluetooth agent confirmation/rejection, trust/connect ordering, and cleanup on a private bus")
        finally:
            server.terminate()
            server.wait(timeout=5)
