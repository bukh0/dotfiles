#!/usr/bin/env python3
"""Validate first launch, toggle, paths with spaces, and dependency-independent errors."""
import os
from pathlib import Path
import subprocess
import tempfile

launcher = Path(__file__).resolve().parents[2] / "clipboard-menu.sh"
if not launcher.exists():
    launcher = Path.home() / ".scripts/clipboard-menu.sh"
with tempfile.TemporaryDirectory(prefix="clipboard-launcher-") as directory:
    root = Path(directory)
    config = root / "config with spaces/quickshell/clipboard"
    config.mkdir(parents=True)
    (config / "shell.qml").touch()
    (config / "backend.py").write_text('print(\'{"address": "0x123"}\')\n')
    binary = root / "quickshell"
    binary.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ["TEST_ROOT"])
with (p/"calls").open("a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")
if sys.argv[1] == "ipc":
    if not (p/"running").exists(): sys.exit(1)
    (p/"running").unlink()
else:
    assert json.loads(os.environ["QS_CLIPBOARD_CONTEXT"])["address"] == "0x123"
    (p/"running").touch()
''')
    binary.chmod(0o755)
    env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
               TEST_ROOT=str(root), XDG_CONFIG_HOME=str(config.parents[1]), XDG_RUNTIME_DIR=str(root))
    for _ in range(2):
        subprocess.run(["bash", str(launcher)], check=True, env=env, capture_output=True)
    assert not (root / "running").exists()
    assert len((root / "calls").read_text().splitlines()) == 3
    (config / "shell.qml").unlink()
    result = subprocess.run(["bash", str(launcher)], env=env, capture_output=True)
    assert result.returncode != 0 and b"Clipboard config not found" in result.stderr
    print("CLIPBOARD LAUNCHER PASS")
