"""Check helper launch failures and late background results in the picker."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="picker-async-") as directory:
    root = Path(directory)
    picker = root / "picker"
    picker.mkdir()
    for name in ("PickerView.qml", "qmldir", "Colors.qml"):
        shutil.copyfile(ROOT / "picker" / name, picker / name)
    engine = root / "engine"
    engine.write_text('''#!/bin/sh
case "$1" in
--list-themes) sleep 0.4; exit 1;;
--list-walls) printf '/tmp/wall.png\\t/tmp/thumb.jpg\\n';;
--thumbs) sleep 1; exit 1;;
--apply) printf 'specific application error\\n' >&2; exit 1;;
esac
''')
    engine.chmod(0o755)
    (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "picker"
ShellRoot {
    Window {
        visible: true; width: 560; height: 300
        PickerView { id: view; anchors.fill: parent; bin: "''' + str(root / "missing") + '''" }
    }
    property int failures: 0
    function check(ok, message) {
        if (!ok) { failures++; console.error("ASYNC FAIL", message, view.error) }
    }
    Timer {
        interval: 700; running: true; repeat: true
        property int step: 0
        onTriggered: {
            switch (step++) {
            case 0:
                view.switchPage("Themes"); break
            case 1:
                check(!view.loading && view.error.length > 0, "Missing listing helper must report an error")
                view.bin = "''' + str(engine) + '''"
                view.refresh()
                view.back(); break
            case 2:
                check(view.error === "", "Late theme-list failure must not leak onto Home")
                view.switchPage("Wallpapers"); break
            case 3:
                view.apply("Preset", ""); break
            case 4:
                check(!view.busy && view.error === "specific application error", "Thumbnail failure must not overwrite an application error")
                view.refresh()
                view.back(); break
            case 5:
                check(view.error === "", "Leaving wallpapers clears page errors")
                break
            case 6:
                check(view.error === "", "Late thumbnail failure must not leak onto Home")
                view.bin = "''' + str(root / "missing") + '''"
                view.apply("Preset", ""); break
            case 7:
                check(!view.busy && view.error.length > 0, "Missing apply helper must release busy state")
                console.log(failures ? "ASYNC FAILED" : "ASYNC PASS")
                Qt.quit()
            }
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory)
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", str(root / "shell.qml")],
                            env=env, capture_output=True, text=True, timeout=12)
    output = result.stdout + result.stderr
    assert "ASYNC PASS" in output and "ASYNC FAIL" not in output, output
    print("PASS: missing helpers, late background failures, and application error preservation")
