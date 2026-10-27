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
    api_changed = "Blueman API changed, pairing helper needs updating"
    try:
        import blueman.main.applet.BluezAgent as agent_module
        from blueman.gui.Notification import _NotificationDialog
        if not callable(_NotificationDialog) or not hasattr(agent_module, "Notification"):
            raise AttributeError("Notification API missing")
        agent_type = agent_module.BluezAgent
        if not all(callable(getattr(agent_type, name, None)) for name in ("register", "unregister")):
            raise AttributeError("Agent lifecycle API missing")
    except (ImportError, AttributeError) as error:
        raise RuntimeError(api_changed) from error

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

    try:
        agent = agent_type()
        agent_path = agent._path
        if not isinstance(agent_path, str) or not GLib.Variant.is_object_path(agent_path):
            raise AttributeError("Agent path missing or invalid")
    except (AttributeError, TypeError) as error:
        raise RuntimeError(api_changed) from error
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

    def connection_warning(error):
        print(f"Bluetooth connection warning: Paired and trusted, but could not connect: {error}", file=sys.stderr)
        finish()

    def connected(connection, result):
        if finished:
            return
        try:
            connection.call_finish(result)
            finish()
        except GLib.Error as error:
            connection_warning(error)

    def trusted(connection, result):
        if finished:
            return
        try:
            connection.call_finish(result)
        except GLib.Error as error:
            finish(error)
            return
        try:
            connection.call("org.bluez", device, "org.bluez.Device1", "Connect", None, None,
                            Gio.DBusCallFlags.NONE, 30000, None, connected)
        except GLib.Error as error:
            connection_warning(error)

    def paired(connection, result):
        if finished:
            return
        try:
            connection.call_finish(result)
        except GLib.Error as error:
            if Gio.DBusError.get_remote_error(error) != "org.bluez.Error.AlreadyExists":
                finish(error)
                return
        try:
            connection.call("org.bluez", device, "org.freedesktop.DBus.Properties", "Set",
                            GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))),
                            None, Gio.DBusCallFlags.NONE, 5000, None, trusted)
        except GLib.Error as error:
            finish(error)

    def cancel():
        if finished:
            return GLib.SOURCE_REMOVE
        try:
            # Do not exit with cancellation still queued on the connection.
            bus.call_sync("org.bluez", device, "org.bluez.Device1", "CancelPairing", None, None,
                          Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass
        finish("Canceled or timed out")
        return GLib.SOURCE_REMOVE

    sources = []
    registration_attempted = False
    try:
        agent.register()
        # Pair on the same connection as our exported agent.
        registration_attempted = True
        bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
                      GLib.Variant("(os)", (agent_path, "KeyboardDisplay")), None,
                      Gio.DBusCallFlags.NONE, 5000, None)
        sources.append(GLib.timeout_add_seconds(150, cancel))
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            sources.append(GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, cancel))
        bus.call("org.bluez", device, "org.bluez.Device1", "Pair", None, None,
                 # Give the cancellation timer time to send CancelPairing first.
                 Gio.DBusCallFlags.NONE, 160000, None, paired)
        loop.run()
    finally:
        for source in sources:
            if GLib.MainContext.default().find_source_by_id(source):
                GLib.source_remove(source)
        try:
            # Also try after a timeout: BlueZ may have registered the agent
            # even if its reply never reached us.
            if registration_attempted:
                bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent",
                              GLib.Variant("(o)", (agent_path,)), None, Gio.DBusCallFlags.NONE, 5000, None)
        except GLib.Error:
            pass
        # Cleanup must not change the result of Pair/Trust/Connect.
        try:
            agent.unregister()
        except Exception:
            pass
        try:
            windows = Gtk.Window.list_toplevels()
        except Exception:
            windows = []
        for window in windows:
            try:
                window.destroy()
            except Exception:
                pass
    return 0 if success else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1]))
    except Exception as error:
        print(f"Bluetooth pairing failed: {error}", file=sys.stderr)
        raise SystemExit(1)
