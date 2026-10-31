"""Launch/reload checks use a fake shell and private PID, lock and log files."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
from harness import ROOT

with tempfile.TemporaryDirectory(prefix="qs-startup-") as directory:
    root = Path(directory)
    (root / "run.sh").write_bytes((ROOT / "run.sh").read_bytes())
    for name in ("profiles/default", "bin", "cache", "runtime", "native"):
        (root / name).mkdir(parents=True)
    for name in ("shell.qml", "Theme.qml"):
        (root / "profiles/default" / name).touch()
    (root / "bin/make").write_text("#!/bin/sh\nexit 0\n")
    (root / "bin/quickshell").write_text('''#!/usr/bin/env python3
import os, sys, time
time.sleep(0.15)
if os.environ["TEST_LOAD"] == "fail":
    print("Failed to load configuration", flush=True)
    sys.exit(1)
print("Configuration Loaded", flush=True)
time.sleep(30)
''')
    for name in ("make", "quickshell"):
        (root / "bin" / name).chmod(0o755)
    env = dict(os.environ, PATH=str(root / "bin") + os.pathsep + os.environ["PATH"],
               XDG_RUNTIME_DIR=str(root / "runtime"), XDG_CACHE_HOME=str(root / "cache"))
    pid_file = root / "runtime" / f"quickshell-{os.getuid()}-default.pid"
    children = []
    def launch(mode):
        return subprocess.run(["bash", str(root / "run.sh")],
                              env=dict(env, TEST_LOAD=mode), capture_output=True,
                              text=True, timeout=15)
    def alive(pid):
        try:
            status = Path(f"/proc/{pid}/status").read_text()
        except FileNotFoundError:
            return False
        return not any(line.startswith("State:") and "Z" in line for line in status.splitlines())
    try:
        (root / "cache/default.log").write_text("Configuration Loaded\n")
        result = launch("fail")
        assert result.returncode != 0 and not pid_file.exists(), result.stdout + result.stderr
        assert "Configuration Loaded" not in (root / "cache/default.log").read_text()
        result = launch("ok")
        assert result.returncode == 0, result.stdout + result.stderr
        first = int(pid_file.read_text())
        children.append(first)
        assert alive(first)
        result = launch("ok")
        assert result.returncode == 0, result.stdout + result.stderr
        second = int(pid_file.read_text())
        children.append(second)
        assert second != first and not alive(first) and alive(second)
    finally:
        if pid_file.exists():
            children.append(int(pid_file.read_text()))
        for pid in set(children):
            if alive(pid):
                os.kill(pid, signal.SIGTERM)
    print("PASS stale-log failure, successful startup and replacement of the previous instance")
