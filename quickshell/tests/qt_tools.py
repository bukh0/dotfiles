"""Locate Qt tools on systems with or without versioned executable names."""
import shutil


def qmltestrunner():
    for name in ("qmltestrunner6", "/usr/lib/qt6/bin/qmltestrunner", "qmltestrunner"):
        found = shutil.which(name)
        if found:
            return found
    raise RuntimeError("Qt 6 qmltestrunner is required for this test")
