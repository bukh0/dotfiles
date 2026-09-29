#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix="clipboard-service-") as runtime:
    profile = Path(runtime) / "profile"
    shutil.copytree(Path(__file__).resolve().parent.parent, profile)
    shutil.copyfile(profile / "tests/service.qml", profile / "shell.qml")
    (profile / "fake_backend.py").write_text('''import json, sys, time
action = sys.argv[1]
result = {}
if action == "context": result = {"address": "0x123"}
if action == "list": result = {"entries": [{"id": "1", "label": "first", "kind": "text"}, {"id": "2", "label": "second", "kind": "text"}]}
if action == "preview":
    time.sleep(0.3 if sys.argv[2] == "1" else 0.01)
    result = {"text": "first" if sys.argv[2] == "1" else "second"}
if action == "copy" and sys.argv[2] == "bad": result = {"error": "Copy failed"}
print(json.dumps(result))
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=runtime)
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", str(profile)], env=env,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
    print(result.stdout)
    assert result.returncode == 0 and "CLIPBOARD SERVICE PASS" in result.stdout
    assert not any(word in result.stdout for word in ("ReferenceError", "TypeError", "Unable to assign", "Failed to load", "Binding loop"))
