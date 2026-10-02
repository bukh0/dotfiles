#!/usr/bin/env python3
"""Pair one device with Blueman dialogs; no persistent applet or default agent."""
import re
import signal
import sys


def main(address):
    if not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", address):
        raise ValueError("Invalid Bluetooth address")

    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gio, GLib, Gtk
    import blueman.main.applet.BluezAgent as agent_module
    from blueman.gui.Notification import _NotificationDialog

    # Keep confirmation/passkey prompts visible even when shell DND is on.
    # This changes only this short-lived helper, not Blueman preferences.
    agent_module.Notification = _NotificationDialog
    if not Gtk.init_check()[0]:
        raise RuntimeError("Could not open Bluetooth pairing dialogs")
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
    objects = bus.call_sync("org.bluez", "/", "org.freedesktop.DBus.ObjectManager",
                            "GetManagedObjects", None, None,
                            Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
    device = next((path for path, interfaces in objects.items()
                   if interfaces.get("org.bluez.Device1", {}).get("Address", "").lower() == address.lower()
                   and objects.get(interfaces["org.bluez.Device1"].get("Adapter"), {})
                   .get("org.bluez.Adapter1", {}).get("Powered", False)), None)
    if device is None:
        raise RuntimeError("Device is no longer available. Scan and try again.")

    agent = agent_module.BluezAgent()
    agent.register()
    # Pair on the SAME Gio connection as the agent, so BlueZ chooses our
    # agent for this request without replacing the session's default agent.
    bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
                  GLib.Variant("(os)", (agent._path, "KeyboardDisplay")), None,
                  Gio.DBusCallFlags.NONE, 5000, None)
    loop = GLib.MainLoop()
    success = False
    finished = False

    def finish(error=None):
        nonlocal success, finished
        if finished:
            return
        finished = True
        success = error is None
        if error:
            print(f"Bluetooth pairing failed: {error}", file=sys.stderr)
        loop.quit()

    def connected(connection, result):
        try:
            connection.call_finish(result)
            finish()
        except GLib.Error as error:
            finish(error)

    def paired(connection, result):
        if finished:
            return
        try:
            connection.call_finish(result)
            connection.call_sync("org.bluez", device, "org.freedesktop.DBus.Properties", "Set",
                                 GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))),
                                 None, Gio.DBusCallFlags.NONE, 5000, None)
            connection.call("org.bluez", device, "org.bluez.Device1", "Connect", None, None,
                            Gio.DBusCallFlags.NONE, 30000, None, connected)
        except GLib.Error as error:
            finish(error)

    def cancel():
        bus.call("org.bluez", device, "org.bluez.Device1", "CancelPairing", None, None,
                 Gio.DBusCallFlags.NONE, 5000, None, None)
        finish("Canceled or timed out")
        return GLib.SOURCE_REMOVE

    timer = GLib.timeout_add_seconds(150, cancel)
    signals = [GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, cancel)
               for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)]
    try:
        bus.call("org.bluez", device, "org.bluez.Device1", "Pair", None, None,
                 Gio.DBusCallFlags.NONE, 120000, None, paired)
        loop.run()
    finally:
        for source in [timer, *signals]:
            if GLib.MainContext.default().find_source_by_id(source):
                GLib.source_remove(source)
        try:
            bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent",
                          GLib.Variant("(o)", (agent._path,)), None, Gio.DBusCallFlags.NONE, 5000, None)
        except GLib.Error:
            pass
        agent.unregister()
        for window in Gtk.Window.list_toplevels():
            window.destroy()
    return 0 if success else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1]))
    except Exception as error:
        print(f"Bluetooth pairing failed: {error}", file=sys.stderr)
        raise SystemExit(1)
