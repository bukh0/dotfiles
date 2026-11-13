"""Restored DND state and masked authentication prompt regressions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
for saved, enabled in [('1', True), ('0', False), ('null', False),
                       ('{"enabled":true,"until":1}', False),
                       ('{"enabled":true,"until":9999999999999}', True),
                       ('{"enabled":true,"until":0}', True)]:
    with tempfile.TemporaryDirectory(prefix='qs-state-') as directory:
        stage = Path(directory)
        shutil.copy(root/'components/NotificationDaemon.qml', stage)
        (stage/'qmldir').write_text('singleton NotificationDaemon 1.0 NotificationDaemon.qml\n')
        (stage/'quickshell_dnd').write_text(saved)
        (stage/'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Timer { interval: 100; running: true; onTriggered: {
  if (NotificationDaemon.doNotDisturb !== EXPECTED) throw new Error("Wrong restored DND")
  NotificationDaemon.setDnd(false)
  console.log("STATE PASS"); Qt.quit()
 } }
}
'''.replace('EXPECTED', str(enabled).lower()))
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CACHE_HOME=directory,
                   XDG_RUNTIME_DIR=directory, DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
        env.pop('WAYLAND_DISPLAY', None)
        result = subprocess.run(['quickshell', '-p', directory], env=env, capture_output=True, text=True, timeout=8)
        assert result.returncode == 0 and 'STATE PASS' in result.stdout+result.stderr, result.stdout+result.stderr
with tempfile.TemporaryDirectory(prefix='qs-askpass-') as directory:
    p = Path(directory)
    zenity = p/'zenity'
    zenity.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\nPath(os.environ["ARGS"]).write_text(json.dumps(sys.argv[1:]))\nsys.exit(int(os.environ["RESULT"]))\n')
    zenity.chmod(0o755)
    env = dict(os.environ, PATH=directory+os.pathsep+os.environ['PATH'], ARGS=str(p/'args'),
               RESULT='0', QS_PERFORMANCE_CANCEL_FILE=str(p/'cancel'))
    prompt = 'Authenticate for <CPU> & GPU settings'
    subprocess.run(['bash', str(root/'native/performance-askpass.sh'), prompt], env=env, check=True)
    argv = json.loads((p/'args').read_text())
    assert '--no-markup' in argv and '--entry' in argv and '--hide-text' in argv and '--text='+prompt in argv
    env['RESULT'] = '1'
    result = subprocess.run(['bash', str(root/'native/performance-askpass.sh'), prompt], env=env)
    assert result.returncode == 1 and (p/'cancel').exists()
print('PASS legacy/rewritten DND state and masked authentication prompt/cancellation')
