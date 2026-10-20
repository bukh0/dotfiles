"""Shared test helpers; transport-dependent singleton stubs stay explicit."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def stub_colors(destination):
    """UI-only QtTest runners cannot load Quickshell's statically linked Io plugin.

    Use palette data for their color singleton. palette_reload.py separately
    loads the real FileView/JsonAdapter singleton in Quickshell.
    """
    colours = json.loads((ROOT / 'components/colors.json').read_text())
    properties = '\n'.join(f'    readonly property color {name}: {json.dumps(value)}'
                           for name, value in colours.items())
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
    import subprocess
    import sys
    print(f'\nRunning {path.stem}', flush=True)
    try:
        return subprocess.run([sys.executable, str(path)], timeout=timeout).returncode == 0
    except subprocess.TimeoutExpired:
        print(f'TIMEOUT: {path.stem}', flush=True)
        return False
