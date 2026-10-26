#!/usr/bin/env python3
"""Exercise abnormal exits, invalid responses and missing Python in isolation."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
quickshell = shutil.which('quickshell')
for mode in ('crash', 'invalid', 'missing'):
    with tempfile.TemporaryDirectory(prefix='clipboard-failure-') as directory:
        root = Path(directory)
        profile = root / 'profile'
        shutil.copytree(ROOT, profile)
        (profile / 'backend.py').write_text('''import json, os, signal, sys
if sys.argv[1] == 'list': print('{"entries": []}')
elif sys.argv[1] == 'copy':
    if os.environ['FAIL_MODE'] == 'crash':
        print('{}', flush=True)
        os.kill(os.getpid(), signal.SIGKILL)
    else: print('null')
else: print('{}')
''')
        (profile / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
    ClipboardService { id: service }
    Timer {
        interval: 800; running: true
        onTriggered: {
            if (service.loading) throw new Error("List stuck loading")
            service.choose("1", false)
            check.start()
        }
    }
    Timer {
        id: check; interval: 800
        onTriggered: {
            if (service.busy || !service.error) throw new Error("Failure not released/reported")
            console.log("FAILURE PASS")
            Qt.quit()
        }
    }
    Connections {
        target: service
        function onCopied(pasteRequested) { throw new Error("Failed process reported success") }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory,
                   QS_CLIPBOARD_CONTEXT='{"address":"0xtest"}', FAIL_MODE=mode)
        env.pop('WAYLAND_DISPLAY', None)
        if mode == 'missing':
            empty = root / 'empty'
            empty.mkdir()
            env['PATH'] = str(empty)
        result = subprocess.run([quickshell, '-p', str(profile)], env=env,
                                capture_output=True, text=True, timeout=8)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'FAILURE PASS' in output, output
        assert 'Error:' not in output, output
        print('PASS', mode)
