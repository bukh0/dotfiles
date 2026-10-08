#!/usr/bin/env python3
"""Verify atomic palette replacements hot-reload a symlinked profile."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
watcher = re.search(r"    FileView \{.*?\n    \}",
                    (ROOT / "components/shell.qml").read_text(), re.S).group()
with tempfile.TemporaryDirectory(prefix="qs-palette-reload-") as directory:
    root = Path(directory)
    components = root / "components"
    profile = root / "profiles/alt"
    components.mkdir()
    profile.mkdir(parents=True)
    palette = components / "Colors.qml"

    def update(colour):
        temporary = components / "Colors.tmp"
        temporary.write_text('pragma Singleton\nimport QtQuick\nQtObject { '
                             'readonly property color primary: "' + colour + '" }\n')
        temporary.replace(palette)

    update("#112233")
    (profile / "Colors.qml").symlink_to(palette)
    (profile / "qmldir").write_text("singleton Colors 1.0 Colors.qml\n")
    (profile / "shell.qml").write_text(
        'import QtQuick\nimport Quickshell\nimport Quickshell.Io\nimport "."\n'
        'ShellRoot {\n' + watcher + '\n'
        'Component.onCompleted: console.log("PALETTE", Colors.primary)\n}\n')
    log_path = root / "log"
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory)
    env.pop("WAYLAND_DISPLAY", None)
    with log_path.open("w") as log:
        process = subprocess.Popen(["quickshell", "-p", str(profile)], env=env,
                                   stdout=log, stderr=log)
        try:
            for index, colour in enumerate(("#112233", "#445566", "#778899")):
                if index:
                    update(colour)
                deadline = time.monotonic() + 5
                while "PALETTE " + colour not in log_path.read_text():
                    assert process.poll() is None and time.monotonic() < deadline, log_path.read_text()
                    time.sleep(0.05)
            assert process.poll() is None, log_path.read_text()
            print("PASS successive atomic palette replacements reload colours in the same process")
        finally:
            process.terminate()
            process.wait(timeout=5)
