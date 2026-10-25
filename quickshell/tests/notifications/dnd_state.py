"""DND persistence across writes and hot reloads, using an isolated cache."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
for scenario in ('existing', 'missing-file', 'missing-directory'):
    with tempfile.TemporaryDirectory(prefix='dnd-state-') as directory:
        p = Path(directory)
        (p/'profile').mkdir()
        shutil.copyfile(ROOT/'components/NotificationDaemon.qml', p/'profile/NotificationDaemon.qml')
        (p/'profile/qmldir').write_text('singleton NotificationDaemon 1.0 NotificationDaemon.qml\n')
        cache = p/'missing'/'cache' if scenario == 'missing-directory' else p
        if scenario == 'existing':
            (cache/'quickshell_dnd').write_text('1\n')
        (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "profile" as Config
ShellRoot {
 PersistentProperties { id: state; property int phase: 0 }
 function check(ok, message) { if (!ok) { console.error("FAIL", message); Qt.quit() } }
 Component.onCompleted: Qt.callLater(() => {
  check(Config.NotificationDaemon.doNotDisturb === (START_ENABLED && state.phase === 0), "restored DND")
  if (state.phase === 0) Config.NotificationDaemon.setDnd(false)
 })
 Timer { interval: 150; running: true; repeat: true
  onTriggered: {
   if (state.phase === 0) {
    check(!Config.NotificationDaemon.doNotDisturb, "stale load overwrote user setting")
    state.phase = 1; Quickshell.reload(false)
   } else if (state.phase === 1) {
    check(!Config.NotificationDaemon.doNotDisturb, "reload turned DND on")
    Config.NotificationDaemon.setDnd(true)
    Config.NotificationDaemon.setDnd(false)
    state.phase = 2
   } else {
    check(!Config.NotificationDaemon.doNotDisturb, "rapid toggles reverted")
    console.log("DND PASS"); Qt.quit()
   }
  }
 }
}
'''.replace('START_ENABLED', 'true' if scenario == 'existing' else 'false'))
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory, XDG_CACHE_HOME=str(cache))
        result = subprocess.run(['quickshell', '-p', str(p/'shell.qml')], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        assert 'DND PASS' in output and 'FAIL' not in output, output
        assert (cache/'quickshell_dnd').read_text().strip() == '0'
        print('PASS DND', scenario, 'startup, writes, hot reload, and rapid toggles')
