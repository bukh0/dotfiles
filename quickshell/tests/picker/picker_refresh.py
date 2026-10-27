"""Refreshes during a running scan must coalesce into one follow-up scan."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="picker-refresh-") as directory:
    root = Path(directory)
    picker = root / "picker"
    picker.mkdir()
    for name in ("PlainToolTip.qml", "PickerView.qml", "qmldir", "Colors.qml"):
        shutil.copyfile(ROOT / "picker" / name, picker / name)
    engine = root / "engine"
    engine.write_text(r"""#!/usr/bin/env python3
import pathlib, sys, time
root = pathlib.Path(__file__).parent
kind = sys.argv[1]
log = root / (kind + ".log")
with log.open("a") as f: f.write("run\n")
new = (root / "new").exists()
time.sleep(0.6)
if kind == "--list-walls":
    print("/tmp/old.png\t/tmp/old-thumb.jpg")
    if new: print("/tmp/new.png\t/tmp/new-thumb.jpg")
elif kind == "--thumbs":
    print("/tmp/new-thumb.jpg" if new else "/tmp/old-thumb.jpg")
""")
    engine.chmod(0o755)
    qml = """
import QtQuick
import Quickshell
import "picker"
ShellRoot {
    Window {
        visible: true; width: 560; height: 600
        PickerView {
            id: view; anchors.fill: parent; bin: ENGINE
            onThumbnailReady: path => { if (path === "/tmp/new-thumb.jpg") owner.ready = true }
        }
    }
    id: owner
    property bool ready: false
    Timer { interval: 50; running: true; onTriggered: view.switchPage("Wallpapers") }
    Timer { interval: 300; running: true; onTriggered: { view.refresh(); view.refresh(); view.refresh() } }
    Timer { interval: 400; running: true; onTriggered: view.busy = true }
    Timer { interval: 900; running: true; onTriggered: {
        if (view.walls.length !== 0 || !view.loading) {
            console.log("REFRESH FAIL completion mutated busy view"); Qt.quit(); return
        }
        view.busy = false
    } }
    Timer {
        interval: 2100; running: true
        onTriggered: {
            console.log(owner.ready && view.walls.length === 2 && !view.loading
                        ? "REFRESH PASS" : "REFRESH FAIL")
            Qt.quit()
        }
    }
}
""".replace("ENGINE", json.dumps(str(engine)))
    (root / "shell.qml").write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory)
    env.pop("WAYLAND_DISPLAY", None)
    proc = subprocess.Popen(["quickshell", "-p", str(root / "shell.qml")],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    deadline = time.monotonic() + 5
    while not (root / "--thumbs.log").exists():
        if time.monotonic() > deadline:
            proc.kill()
            raise AssertionError(proc.communicate())
        time.sleep(0.01)
    (root / "new").touch()
    out, err = proc.communicate(timeout=8)
    assert "REFRESH PASS" in out + err, out + err
    for kind in ("--list-walls", "--thumbs"):
        assert (root / (kind + ".log")).read_text().splitlines() == ["run", "run"]
    print("PASS: repeated refreshes coalesce; new wallpaper and thumbnail appear")
