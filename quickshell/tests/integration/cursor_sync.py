"""Exercise cursor settings signals without changing the user's desktop."""
import importlib.util
import os
from pathlib import Path
import subprocess
from unittest import mock

os.environ['GSETTINGS_BACKEND'] = 'memory'
source = Path(os.environ.get('REVIEW_CURSOR_SCRIPT', str(Path.home() / '.scripts/gtk-cursor-sync.py')))
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from harness import require_external_files
require_external_files(source)

spec = importlib.util.spec_from_file_location('cursor_sync', source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
settings = module.Gio.Settings.new('org.gnome.desktop.interface')
settings.set_string('cursor-theme', 'Qogir-Dark')
settings.set_int('cursor-size', 24)
sync = module.CursorSync(settings)
with mock.patch.object(module, 'run') as run:
    sync.apply()
    assert run.call_args_list[1].args[0] == ['hyprctl', 'setcursor', 'Qogir-Dark', '24']
    assert run.call_args_list[2].args[0][-2:] == ['XCURSOR_THEME=Qogir-Dark', 'XCURSOR_SIZE=24']
    run.reset_mock()
    settings.set_string('cursor-theme', 'Adwaita')
    settings.set_int('cursor-size', 32)
    loop = module.GLib.MainLoop()
    module.GLib.timeout_add(300, lambda: (loop.quit(), False)[1])
    loop.run()
    assert run.call_count == 3, run.call_args_list
    assert run.call_args_list[1].args[0] == ['hyprctl', 'setcursor', 'Adwaita', '32']
    run.reset_mock()
    settings.set_string('gtk-theme', 'Adwaita')
    assert not sync.pending
    assert run.call_count == 0
print('PASS initial cursor application, live theme/size signals, coalescing and unrelated settings')
with mock.patch.object(module.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'failed to set cursor\n', '')):
    try:
        module.run(['hyprctl', 'setcursor', 'missing', '24'])
    except RuntimeError:
        pass
    else:
        raise AssertionError('hyprctl error response was treated as success')
with mock.patch.object(module, 'run', side_effect=OSError('unavailable')):
    sync.apply()
    assert sync.pending
    module.GLib.source_remove(sync.pending)
    sync.pending = 0
# Ensure theme names cannot escape the generated Lua string.
for theme in ['a"; os.execute("false")', 'a]]b]=]c', "theme's name", r'a\b']:
    result = subprocess.run(['lua', '-e', 'io.write(' + module.lua_string(theme) + ')'],
                            capture_output=True, text=True, check=True)
    assert result.stdout == theme
print('PASS failed compositor responses, retry scheduling and literal theme-name handling')
