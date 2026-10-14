"""Exercise absent-backlight backoff and immediate panel-open recovery with a mock."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-brightness-discovery-') as directory:
    stage = Path(directory)
    profile = stage / 'profile'
    profile.mkdir()
    bins = stage / 'bin'
    bins.mkdir()
    backlight = stage / 'backlight' / 'mock'
    backlight.mkdir(parents=True)
    (backlight / 'brightness').write_text('50\n')
    calls = stage / 'calls'
    calls.touch()
    ready = stage / 'ready'
    ready.write_text('')
    source = (ROOT / 'components/BrightnessService.qml').read_text()
    # Accelerate only the retry schedule; retain real Process/FileView behavior.
    source = source.replace('Math.min(300000, 10000 *', 'Math.min(800, 50 *')
    source = source.replace('"/sys/class/backlight/"', repr(str(backlight.parent) + '/'))
    (profile / 'BrightnessService.qml').write_text(source)
    (profile / 'qmldir').write_text('singleton BrightnessService 1.0 BrightnessService.qml\n')
    mock = bins / 'brightnessctl'
    mock.write_text('''#!/usr/bin/env python3
from pathlib import Path
import os, sys, time
with open(os.environ['TEST_CALLS'], 'a') as f: f.write(str(time.monotonic()) + '\\n')
if Path(os.environ['TEST_READY']).read_text().strip() != 'yes': sys.exit(1)
print('mock,backlight,50,50%,100')
''')
    mock.chmod(0o755)
    (stage / 'test.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "profile" as Config
ShellRoot {
 id: root
 property int phase: 0
 property int ticks: 0
 FileView { id: ready; path: Quickshell.env("TEST_READY"); atomicWrites: false }
 Component.onCompleted: Config.BrightnessService.discover()
 Timer {
  interval: 25; running: true; repeat: true
  onTriggered: {
   const service = Config.BrightnessService
   if (++root.ticks > 200) { console.error("FAIL discovery timeout"); Qt.quit(); return }
   if (root.phase === 0 && service._discoveryAttempts >= 5) {
    if (service.discoveryRetryMs !== 800 || service.available) {
     console.error("FAIL missing-device backoff"); Qt.quit(); return
    }
    // Let the failed child finish; retry immediately on watcher entry,
    // well before the 800ms backoff expires.
    root.phase = 1
    recover.start()
   }
   if (root.phase === 2 && service.available) {
    if (service._discoveryAttempts !== 0 || service.discoveryRetryMs !== 50) {
     console.error("FAIL recovery did not reset backoff"); Qt.quit(); return
    }
    console.log("PASS missing-backlight backoff and watcher-triggered recovery")
    Qt.quit()
   }
  }
 }
 Timer {
  id: recover; interval: 120
  onTriggered: { ready.setText("yes"); openPanel.start() }
 }
 Timer {
  id: openPanel; interval: 40
  onTriggered: { root.phase = 2; Config.BrightnessService.watchers = 1 }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory,
               PATH=str(bins) + os.pathsep + os.environ['PATH'],
               TEST_CALLS=str(calls), TEST_READY=str(ready))
    result = subprocess.run(['quickshell', '-p', str(stage / 'test.qml')], env=env,
                            text=True, capture_output=True, timeout=10)
    print(result.stdout + result.stderr)
    assert result.returncode == 0 and 'PASS missing-backlight' in result.stdout + result.stderr
    times = [float(s) for s in calls.read_text().splitlines()]
    assert len(times) == 6, times
    intervals = [b-a for a,b in zip(times, times[1:])]
    assert intervals[2] > intervals[0] * 1.8 and intervals[3] > intervals[1] * 1.8, intervals
    assert intervals[4] < 0.7, ('Panel-open retry waited for backoff', intervals)
