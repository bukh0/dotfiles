from pathlib import Path
import shutil


def qmltestrunner():
    for candidate in ('/usr/lib/qt6/bin/qmltestrunner', shutil.which('qmltestrunner6')):
        if candidate and Path(candidate).is_file():
            return candidate
    raise RuntimeError('Qt 6 qmltestrunner is required')
