#!/usr/bin/env python3
"""Load the actual view with synthetic history and validate its model."""
import os
from pathlib import Path
import subprocess
import tempfile
import shutil

with tempfile.TemporaryDirectory(prefix="clipboard-ui-") as runtime:
    profile = Path(runtime) / "profile"
    shutil.copytree(Path(__file__).resolve().parent.parent, profile)
    (profile / "shell.qml").write_text((profile / "tests/preview.qml").read_text().replace('import ".."', 'import "."'))
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=runtime,
               QT_QUICK_BACKEND="software")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", str(profile)],
                            env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=15)
    print(result.stdout)
    assert result.returncode == 0 and "CLIPBOARD UI PASS" in result.stdout
    assert not any(word in result.stdout for word in ("ReferenceError", "TypeError", "Unable to assign", "Failed to load", "Binding loop"))
