"""Bound a stuck apply, cancel its descendants, then allow another attempt."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-picker-cancel-') as directory:
    p = Path(directory)
    shutil.copytree(ROOT / 'picker', p / 'picker', ignore=shutil.ignore_patterns('__pycache__'))
    engine = p / 'engine'
    engine.write_text('''#!/bin/sh
if [ "$1" = --apply ]; then
 (sleep 4; echo survived >> "$TEST_SURVIVORS") &
 wait
fi
''')
    engine.chmod(0o755)
    (p / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "picker"
ShellRoot {
 Window { visible: true; width: 820; height: 600
  PickerView { id: view; anchors.fill: parent; bin: "''' + str(engine) + '''"; operationTimeoutSeconds: 1 }
 }
 property int step: 0
 property int ticks: 0
 function fail(message) { console.error("CANCEL FAIL", message); Qt.quit() }
 Timer { interval: 50; repeat: true; running: true
  onTriggered: {
   if (++ticks > 160) { fail("fixture timeout"); return }
   if (step === 0) { view.apply("Stuck", ""); step++ }
   else if (step === 1 && !view.busy) {
    if (!view.error.includes("timed out")) { fail(view.error); return }
    view.operationTimeoutSeconds = 30; view.apply("Cancel", ""); step++; ticks = 0
   } else if (step === 2 && ticks > 6) {
    view.handleKey({key: Qt.Key_Escape, modifiers: Qt.NoModifier, accepted: false}); step++
   } else if (step === 3 && !view.busy) {
    if (!view.error.includes("cancelled")) { fail(view.error); return }
    step++; ticks = 0
   } else if (step === 4 && ticks > 90) { console.log("CANCEL PASS"); Qt.quit() }
  }
 }
}
''')
    survivors = p / 'survivors'
    r = subprocess.run(['quickshell', '-p', str(p)], env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory, TEST_SURVIVORS=str(survivors)), capture_output=True, text=True, timeout=15)
    output = r.stdout + r.stderr
    assert 'CANCEL PASS' in output and 'CANCEL FAIL' not in output, output
    assert not survivors.exists(), 'apply left a running descendant'
    print('PASS apply timeout, Escape cancellation, retry and descendant cleanup')
