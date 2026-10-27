"""Shared test helpers; transport-dependent singleton stubs stay explicit."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def require_external_files(*paths):
    """Mark unavailable desktop integration inputs as skipped, never passed."""
    missing = [str(path) for path in paths if not Path(path).is_file()]
    if missing:
        print('SKIP: external integration files unavailable: ' + ', '.join(missing), flush=True)
        raise SystemExit(77)


def stub_colors(destination):
    """UI-only QtTest runners cannot load Quickshell's statically linked Io plugin.

    Use palette data for their color singleton. palette_reload.py separately
    loads the real FileView/JsonAdapter singleton in Quickshell.
    """
    colours = json.loads((ROOT / 'components/colors.json').read_text())
    properties = []
    for name, value in colours.items():
        expression = json.dumps(value)
        # Match Colors.qml's optional derived shades for palettes without them.
        if not value and name in ('surfaceContainer', 'surfaceContainerHigh'):
            alpha = '0.06' if name == 'surfaceContainer' else '0.12'
            expression = f'Qt.tint(surface, Qt.rgba(surfaceFg.r, surfaceFg.g, surfaceFg.b, {alpha}))'
        properties.append(f'    readonly property color {name}: {expression}')
    properties = '\n'.join(properties)
    Path(destination).write_text('pragma Singleton\nimport QtQuick\nQtObject {\n' + properties + '\n}\n')


def stub_mpris(directory):
    """Inject only the native transport/enum; load MusicService unchanged."""
    module = Path(directory) / 'Quickshell/Services/Mpris'
    module.mkdir(parents=True)
    (module / 'qmldir').write_text('module Quickshell.Services.Mpris\nsingleton Mpris 1.0 Mpris.qml\nsingleton MprisPlaybackState 1.0 MprisPlaybackState.qml\n')
    (module / 'Mpris.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var players: ({values: []}) }\n')
    (module / 'MprisPlaybackState.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { enum State { Stopped, Playing, Paused } }\n')


def run_suite(path, timeout=240):
    """Use the current interpreter, report failures, and bound a hung fixture."""
    import os
    import subprocess
    import sys
    print(f'\nRunning {path.stem}', flush=True)
    try:
        env = dict(os.environ)
        # Nested suites share helpers without depending on the working directory.
        helpers = str(Path(__file__).resolve().parent)
        env['PYTHONPATH'] = helpers + (os.pathsep + env['PYTHONPATH'] if env.get('PYTHONPATH') else '')
        code = subprocess.run([sys.executable, str(path)], env=env, timeout=timeout).returncode
        return None if code == 77 else code == 0
    except subprocess.TimeoutExpired:
        print(f'TIMEOUT: {path.stem}', flush=True)
        return False
