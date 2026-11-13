#!/usr/bin/env python3
"""Adapter-aware BlueZ actions; discovery owns and releases its D-Bus session."""
import signal
import subprocess
import sys


def main(action, argument=""):
    from gi.repository import Gio, GLib
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)

    def call(path, interface, method, parameters=None, timeout=10000):
        return bus.call_sync("org.bluez", path, interface, method, parameters,
                             None, Gio.DBusCallFlags.NONE, timeout, None)

    objects = call("/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects").unpack()[0]
    adapters = {path: interfaces["org.bluez.Adapter1"] for path, interfaces in objects.items()
                if "org.bluez.Adapter1" in interfaces}
    if action == "power":
        if argument not in ("on", "off"):
            raise ValueError("Invalid power state")
        if not adapters:
            raise RuntimeError("No Bluetooth adapter is available")
        if argument == "on":
            subprocess.run(["rfkill", "unblock", "bluetooth"], check=True, timeout=5)
        errors = []
        for path in adapters:
            try:
                call(path, "org.freedesktop.DBus.Properties", "Set",
                     GLib.Variant("(ssv)", ("org.bluez.Adapter1", "Powered", GLib.Variant("b", argument == "on"))))
            except GLib.Error as error:
                errors.append(str(error))
        if errors:
            raise RuntimeError("; ".join(errors))
    elif action in ("connect", "disconnect"):
        device = objects.get(argument, {}).get("org.bluez.Device1")
        if not device:
            raise RuntimeError("Device is no longer available. Scan and try again.")
        call(argument, "org.bluez.Device1", "Connect" if action == "connect" else "Disconnect", timeout=30000)
    elif action == "scan":
        duration = max(1, min(30, int(argument)))
        started = []
        errors = []
        loop = GLib.MainLoop()
        def stop(*_):
            loop.quit()
            return GLib.SOURCE_REMOVE
        try:
            for path, adapter in adapters.items():
                if adapter.get("Powered"):
                    try:
                        call(path, "org.bluez.Adapter1", "StartDiscovery")
                        started.append(path)
                    except GLib.Error as error:
                        errors.append(f"{path}: {error}")
            if not started:
                raise RuntimeError("; ".join(errors) or "No powered Bluetooth adapter is available")
            if errors:
                print("Bluetooth scan warning: " + "; ".join(errors), file=sys.stderr)
            GLib.timeout_add_seconds(duration, stop)
            for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
                GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, stop)
            loop.run()
        finally:
            for path in started:
                try:
                    call(path, "org.bluez.Adapter1", "StopDiscovery", timeout=2000)
                except GLib.Error:
                    pass
    else:
        raise ValueError("Unknown Bluetooth action")


if __name__ == "__main__":
    try:
        main(*sys.argv[1:])
    except Exception as error:
        print(f"Bluetooth action failed: {error}", file=sys.stderr)
        sys.exit(1)
