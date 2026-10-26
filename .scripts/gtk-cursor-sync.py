#!/usr/bin/env python3
"""Follow nwg-look's GSettings cursor selection in Hyprland and new apps."""
import argparse
import subprocess
import sys
from gi.repository import Gio, GLib


def lua_string(value):
    # Long strings preserve quotes/backslashes without interpreting Lua code.
    equals = ''
    while ']' + equals + ']' in value:
        equals += '='
    return '[' + equals + '[' + value + ']' + equals + ']'


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=5, check=True)
    if args[0] == 'hyprctl' and result.stdout.strip() != 'ok':
        raise RuntimeError(result.stdout.strip() or result.stderr.strip())


class CursorSync:
    def __init__(self, settings):
        self.settings = settings
        self.pending = 0
        settings.connect('changed::cursor-theme', self.changed)
        settings.connect('changed::cursor-size', self.changed)

    def changed(self, *_):
        if self.pending:
            GLib.source_remove(self.pending)
        self.pending = GLib.timeout_add(150, self.apply)

    def apply(self):
        self.pending = 0
        theme = self.settings.get_string('cursor-theme')
        size = self.settings.get_int('cursor-size')
        if not theme or any(ord(c) < 32 for c in theme) or size <= 0:
            print('Invalid cursor selection; keeping the previous cursor.', file=sys.stderr, flush=True)
            return GLib.SOURCE_REMOVE
        try:
            run(['hyprctl', 'eval', 'hl.env("XCURSOR_THEME", ' + lua_string(theme)
                 + '); hl.env("XCURSOR_SIZE", ' + lua_string(str(size)) + ')'])
            run(['hyprctl', 'setcursor', theme, str(size)])
            run(['dbus-update-activation-environment', '--systemd',
                 'XCURSOR_THEME=' + theme, 'XCURSOR_SIZE=' + str(size)])
            print(f'Applied cursor: {theme} ({size})', flush=True)
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            print(f'Cursor sync failed: {error}; retrying in 5s', file=sys.stderr, flush=True)
            self.pending = GLib.timeout_add_seconds(5, self.apply)
        return GLib.SOURCE_REMOVE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--theme', action='store_true')
    parser.add_argument('--size', action='store_true')
    args = parser.parse_args()
    settings = Gio.Settings.new('org.gnome.desktop.interface')
    if args.theme:
        print(settings.get_string('cursor-theme') or 'Adwaita')
    elif args.size:
        print(max(1, settings.get_int('cursor-size')))
    else:
        sync = CursorSync(settings)
        sync.apply()
        GLib.MainLoop().run()


if __name__ == '__main__':
    main()
