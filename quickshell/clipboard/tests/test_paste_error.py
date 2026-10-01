"""The closed clipboard popup stays closed when automatic paste fails."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='clipboard-paste-error-') as d:
    root = Path(d)
    profile = root / 'profile'
    shutil.copytree(ROOT, profile)
    text = (ROOT / 'shell.qml').read_text()
    text = text.replace('PanelWindow {', 'FloatingWindow {')
    text = text.replace('        id: window', '        id: window\n        implicitWidth: 1000; implicitHeight: 700')
    text = re.sub(r'^        (anchors \{.*|exclusionMode:.*|WlrLayershell\..*)\n', '', text, flags=re.M)
    text = text.replace('    id: root', '''    id: root
    Timer { interval: 200; running: true; onTriggered: clipboardBackend.choose("1", true) }''')
    (profile / 'shell.qml').write_text(text)
    (profile / 'backend.py').write_text('''import json,sys
print(json.dumps({'entries': []} if sys.argv[1] == 'list' else {'error': 'Copied. Focus changed; paste skipped.'} if sys.argv[1] == 'paste' else {}))
''')
    notify = root / 'notify-send'
    notify.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$TEST_NOTICE"\n')
    notify.chmod(0o755)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=d,
               PATH=d+os.pathsep+os.environ['PATH'], TEST_NOTICE=str(root/'notice'),
               QS_CLIPBOARD_CONTEXT='{"address":"0xtest"}')
    env.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['quickshell', '-p', str(profile)], env=env,
                            capture_output=True, text=True, timeout=8)
    assert result.returncode == 0, result.stdout+result.stderr
    for _ in range(20):
        if (root/'notice').exists(): break
        time.sleep(.05)
    assert 'Copied. Focus changed' in (root/'notice').read_text()
    print('PASS paste failure notifies and exits without reopening the popup')
