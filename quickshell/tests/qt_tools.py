"""Locate Qt 6 test tools without accidentally selecting a Qt 5 runner."""
from pathlib import Path
import shutil
import subprocess


def qmltestrunner():
    for name in ("qmltestrunner6", "qmltestrunner-qt6"):
        if runner := shutil.which(name):
            return runner
    if qmake := shutil.which("qmake6"):
        result = subprocess.run([qmake, "-query", "QT_INSTALL_BINS"],
                                capture_output=True, text=True, timeout=5)
        runner = Path(result.stdout.strip()) / "qmltestrunner"
        if result.returncode == 0 and runner.is_file():
            return str(runner)
    fallback = Path("/usr/lib/qt6/bin/qmltestrunner")
    if fallback.is_file():
        return str(fallback)
    if runner := shutil.which("qmltestrunner"):
        return runner
    raise RuntimeError("Qt 6 qmltestrunner is required")
