#!/usr/bin/env python3
"""Check launcher locking and profile validation without touching the real shell."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="quickshell-launcher-") as directory:
    stage = Path(directory)
    shutil.copyfile(ROOT / "run.sh", stage / "run.sh")
    (stage / "profiles" / "default").mkdir(parents=True)
    for name in ("shell.qml", "Theme.qml"):
        (stage / "profiles" / "default" / name).touch()
    (stage / "native").mkdir()
    (stage / "native" / "Makefile").write_text(
        "all:\n\t@if ! mkdir build-lock 2>/dev/null; then touch build-race; exit 1; fi\n"
        "\t@sleep 0.2\n\t@rmdir build-lock\n")
    binary_dir = stage / "bin"
    binary_dir.mkdir()
    binary = binary_dir / "quickshell"
    binary.write_text("#!/usr/bin/env python3\nimport os, time\n"
                      "if os.environ.get('TEST_PROCESS_LOG'):\n"
                      " with open(os.environ['TEST_PROCESS_LOG'], 'a') as f: f.write(str(os.getpid()) + '\\n')\n"
                      "time.sleep(0.8)\n"
                      "if os.environ.get('TEST_LOAD_FAIL'): raise SystemExit(1)\n"
                      "print('Configuration Loaded', flush=True)\n"
                      "time.sleep(30)\n")
    binary.chmod(0o755)
    runtime = stage / "runtime"
    runtime.mkdir()
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(stage / "cache"),
               TEST_PROCESS_LOG=str(stage / "started"),
               PATH=str(binary_dir) + os.pathsep + os.environ["PATH"])
    pid_file = runtime / f"quickshell-{os.getuid()}-default.pid"
    unrelated = subprocess.Popen([str(binary), "-p", str(stage / "clipboard")])
    try:
        invalid = subprocess.run(["bash", str(stage / "run.sh"), "shared"], env=env,
                                 capture_output=True, timeout=5)
        assert invalid.returncode == 1 and not pid_file.exists()
        # Simulate a stale PID reused by the standalone clipboard application.
        pid_file.write_text(str(unrelated.pid))
        first = subprocess.Popen(["bash", str(stage / "run.sh")], env=env)
        second = subprocess.Popen(["bash", str(stage / "run.sh")], env=env)
        assert first.wait(timeout=8) == 0
        assert second.wait(timeout=8) == 0
        assert unrelated.poll() is None, "stale PID file killed another Quickshell application"
        assert not (stage / "native" / "build-race").exists(), "concurrent native builds"
        pid = int(pid_file.read_text())
        os.kill(pid, 0)
        assert b"quickshell" in Path(f"/proc/{pid}/cmdline").read_bytes()
        started = [int(value) for value in (stage / "started").read_text().splitlines()]
        assert len(started) == 2, started
        for previous in started:
            if previous == pid:
                continue
            status = Path(f"/proc/{previous}/status")
            assert not status.exists() or "State:\tZ" in status.read_text(), "previous bar was not stopped"
        failed = subprocess.run(["bash", str(stage / "run.sh")], env=dict(env, TEST_LOAD_FAIL="1"), capture_output=True, timeout=5)
        assert failed.returncode == 1 and not pid_file.exists(), "slow load failure was reported as success"
        print("REGRESSION PASS: launcher")
    finally:
        unrelated.terminate()
        unrelated.wait(timeout=5)
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), signal.SIGTERM)
            except ProcessLookupError:
                pass
