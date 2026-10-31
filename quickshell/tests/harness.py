"""Shared helpers for isolated configuration tests."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent


def require_external_files(*paths):
    missing = [str(path) for path in paths if not Path(path).is_file()]
    if missing:
        print("SKIP: missing external files: " + ", ".join(missing))
        sys.exit(77)


def stub_colors(path):
    # Use the default palette without reading or watching the user's files.
    import json
    palette = json.loads((ROOT / "components/colors.json").read_text())
    declarations = [f"    readonly property color {key}: {json.dumps(value)}"
                    for key, value in palette.items()]
    Path(path).write_text("pragma Singleton\nimport QtQuick\nQtObject {\n"
                          + "\n".join(declarations) + "\n}\n")


def run_qml(stage, marker, timeout=10):
    import os
    import subprocess
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               XDG_RUNTIME_DIR=str(stage))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", str(stage)], env=env,
                            capture_output=True, text=True, timeout=timeout)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and marker in output, output
    assert not any(message in output for message in
                   ("ReferenceError", "TypeError", "Unable to assign", "Failed to load", "Binding loop")), output
