#!/usr/bin/env python3
"""Atomic JSON palettes update the real singleton without rebuilding the shell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="qs-palette-live-") as directory:
    root = Path(directory)
    components = root / "components"
    profile = root / "profiles/alt"
    components.mkdir()
    profile.mkdir(parents=True)
    shutil.copyfile(os.environ.get('QS_TEST_COLORS', ROOT / 'components/Colors.qml'), components / 'Colors.qml')
    palette = components / 'colors.json'

    def update(value):
        temporary = components / 'colors.tmp'
        temporary.write_text(value if isinstance(value, str) else json.dumps(value))
        temporary.replace(palette)

    update({'primary': '#112233'})
    for name in ['Colors.qml', 'colors.json']:
        (profile / name).symlink_to(components / name)
    (profile / 'qmldir').write_text('singleton Colors 1.0 Colors.qml\n')
    (profile / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
    property color colour: Colors.primary
    onColourChanged: console.log("PALETTE", colour)
    property color container: Colors.surfaceContainer
    onContainerChanged: console.log("CONTAINER", container)
    Component.onCompleted: console.log("ROOT_CREATED")
}
''')
    log_path = root / 'log'
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory)
    env.pop('WAYLAND_DISPLAY', None)
    with log_path.open('w') as log:
        process = subprocess.Popen(['quickshell', '-p', str(profile)], env=env, stdout=log, stderr=log)
        def await_colour(colour):
            deadline = time.monotonic() + 5
            while 'PALETTE ' + colour not in log_path.read_text():
                assert process.poll() is None and time.monotonic() < deadline, log_path.read_text()
                time.sleep(.05)
        try:
            await_colour('#112233')
            update({'primary': '#445566'})
            await_colour('#445566')
            update('{invalid json')
            time.sleep(.2)
            update({'primary': '#778899', 'surface': '#000000', 'surfaceFg': '#ffffff', 'surfaceContainer': '', 'surfaceContainerHigh': ''})
            await_colour('#778899')
            assert 'CONTAINER #0f0f0f' in log_path.read_text(), log_path.read_text()
            assert log_path.read_text().count('ROOT_CREATED') == 1, log_path.read_text()
            print('PASS atomic JSON palette updates and recovery without shell reload')
        finally:
            process.terminate()
            process.wait(timeout=5)
