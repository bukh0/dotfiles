"""Bound a stuck apply, cancel its descendants, then allow another attempt."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[2]
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
import QtTest
import "picker"
ShellRoot {
 Window { id: window; visible: true; width: 820; height: 600
  TestCase { id: input; when: false }
  PickerView { id: view; anchors.fill: parent; bin: "''' + str(engine) + '''"; operationTimeoutSeconds: 1 }
 }
 property int step: 0
 property int ticks: 0
 property int cancelMethod: 0
 function fail(message) { console.error("CANCEL FAIL", step, ticks, message); Qt.quit() }
 Timer { interval: 50; repeat: true; running: true
  onTriggered: {
   if (++ticks > 160) { fail("fixture timeout"); return }
   if (step === 0) { window.requestActivate(); view.focusSearch(); view.apply("Stuck", ""); step++ }
   else if (step === 1 && !view.busy) {
    if (!view.error.includes("timed out")) { fail(view.error); return }
    view.operationTimeoutSeconds = 30; view.focusSearch(); view.apply("Cancel", ""); step++; ticks = 0
   } else if (step === 2 && ticks > 6) {
    if (cancelMethod === 0) input.keyClick(Qt.Key_Escape)
    else if (cancelMethod === 1) input.keyClick(Qt.Key_C, Qt.ControlModifier)
    else {
     const close = input.findChild(view, "pickerClose")
     input.mouseClick(close, close.width / 2, close.height / 2)
    }
    if (!view.operationCancelled) { fail("input did not cancel"); return }
    step++
   } else if (step === 3 && !view.busy) {
    if (!view.error.includes("cancelled")) { fail(view.error); return }
    if (++cancelMethod < 3) {
     view.focusSearch()
     const search = input.findChild(view, "pickerSearch")
     search.text = "selected text"; search.selectAll()
     view.apply("Cancel", ""); step = 2; ticks = 0
    } else { step++; ticks = 0 }
   } else if (step === 4 && ticks > 90) { console.log("CANCEL PASS"); Qt.quit() }
  }
 }
}
''')
    survivors = p / 'survivors'
    r = subprocess.run(['quickshell', '-p', str(p)], env=dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=directory, TEST_SURVIVORS=str(survivors)), capture_output=True, text=True, timeout=20)
    output = r.stdout + r.stderr
    assert 'CANCEL PASS' in output and 'CANCEL FAIL' not in output, output
    assert not survivors.exists(), 'apply left a running descendant'
    print('PASS apply timeout, real Escape/Ctrl+C/close-click cancellation, retry and descendant cleanup')
