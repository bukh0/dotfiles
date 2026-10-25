"""Signal only the wrapper; its tracked child must still stop."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

source = Path(os.environ.get("REVIEW_SCRIPTS_DIR", str(Path.home() / ".scripts"))) / "wayclick/dusky_wayclick.sh"
# Load the real trap/functions without installing anything or opening input devices.
prefix = source.read_text().split("if (( EUID == 0 )); then", 1)[0]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    wrapper = root / "wrapper.sh"
    wrapper.write_text(prefix + '\nsleep 60 &\nRUNNER_PID=$!\nprintf "%s" "$RUNNER_PID" > "$HOME/child"\nwait "$RUNNER_PID"\n')
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        (root / "child").unlink(missing_ok=True)
        proc = subprocess.Popen(["bash", str(wrapper)], env=dict(os.environ, HOME=directory),
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        child = None
        try:
            for _ in range(100):
                if (root / "child").exists() and (root / "child").read_text():
                    break
                time.sleep(0.02)
            child = int((root / "child").read_text())
            proc.send_signal(sig)
            _, stderr = proc.communicate(timeout=5)
            assert proc.returncode == 128 + sig, stderr
            assert not Path(f"/proc/{child}").exists(), "runner survived wrapper signal"
            assert (root / ".config/dusky/settings/wayclick").read_text().strip() == "False"
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            if child is not None:
                try:
                    os.kill(child, signal.SIGKILL)
                except ProcessLookupError:
                    pass
print("PASS WayClick forwards termination, reaps its child, and resets state")
