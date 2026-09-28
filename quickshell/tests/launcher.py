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
    (stage / "native" / "Makefile").write_text("all:\n\t@true\n")
    binary_dir = stage / "bin"
    binary_dir.mkdir()
    binary = binary_dir / "quickshell"
    binary.write_text("#!/usr/bin/env python3\nimport time\ntime.sleep(30)\n")
    binary.chmod(0o755)
    runtime = stage / "runtime"
    runtime.mkdir()
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(stage / "cache"),
               PATH=str(binary_dir) + os.pathsep + os.environ["PATH"])
    pid_file = runtime / f"quickshell-{os.getuid()}-default.pid"
    try:
        invalid = subprocess.run(["bash", str(stage / "run.sh"), "shared"], env=env,
                                 capture_output=True, timeout=5)
        assert invalid.returncode == 1 and not pid_file.exists()
        first = subprocess.Popen(["bash", str(stage / "run.sh")], env=env)
        second = subprocess.Popen(["bash", str(stage / "run.sh")], env=env)
        assert first.wait(timeout=8) == 0
        assert second.wait(timeout=8) == 0
        pid = int(pid_file.read_text())
        os.kill(pid, 0)
        assert b"quickshell" in Path(f"/proc/{pid}/cmdline").read_bytes()
        print("REGRESSION PASS: launcher")
    finally:
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), signal.SIGTERM)
            except ProcessLookupError:
                pass
