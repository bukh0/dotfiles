#!/usr/bin/env python3
"""Repeated inspect calls preserve debounce; selection bounces don't duplicate work."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='clipboard-preview-') as directory:
    root = Path(directory)
    profile = root / 'profile'
    shutil.copytree(ROOT, profile)
    service = profile / 'ClipboardService.qml'
    # Expose the process only in this isolated test profile to synchronize the bounce.
    service.write_text(service.read_text().replace('id: service',
        'id: service\n    property alias testPreviewProcess: previewProcess', 1))
    (profile / 'backend.py').write_text('''import json, os, sys
from pathlib import Path
if sys.argv[1] == 'preview':
    with (Path(os.environ['XDG_RUNTIME_DIR'])/'requests').open('a') as log:
        log.write(sys.argv[2] + '\\n')
    print(json.dumps({'text': sys.argv[2]}))
elif sys.argv[1] == 'list': print('{"entries": []}')
else: print('{}')
''')
    (profile / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
    ClipboardService { id: service }
    Connections {
        target: service.testPreviewProcess
        function onStarted() {
            if (service.previewId === "2") {
                service.inspect("3")
                service.inspect("2")
            }
        }
    }
    Timer {
        interval: 20; running: true; repeat: true
        onTriggered: service.inspect("1")
        id: repeated
    }
    Timer {
        interval: 700; running: true
        onTriggered: {
            repeated.stop()
            if (service.preview.text !== "1") throw new Error("Repeated inspect starved preview")
            service.inspect("2")
            check.start()
        }
    }
    Timer {
        id: check; interval: 700
        onTriggered: {
            if (service.preview.text !== "2" || service.previewLoading)
                throw new Error("Bounce preview did not settle")
            console.log("PREVIEW REQUESTS PASS")
            Qt.quit()
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory,
               QS_CLIPBOARD_CONTEXT='{"address":"0xtest"}')
    env.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['quickshell', '-p', str(profile)], env=env,
                            capture_output=True, text=True, timeout=8)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PREVIEW REQUESTS PASS' in output, output
    assert 'Error:' not in output, output
    assert (root / 'requests').read_text().splitlines() == ['1', '2']
    print('PASS repeated inspect and running preview bounce issue exactly one request per ID')
