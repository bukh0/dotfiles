"""Exercise picker exit/collector callbacks without changing a wallpaper."""
from pathlib import Path
import shutil
import tempfile
from harness import ROOT, run_qml

with tempfile.TemporaryDirectory(prefix="qs-picker-results-") as directory:
    stage = Path(directory)
    shutil.copytree(ROOT / "picker", stage / "profile")
    profile = stage / "profile"
    source = (profile / "PickerView.qml").read_text()
    source = source.replace("id: view", """id: view
    property alias testWallpaper: wallpaperProc
    property alias testApply: applyProc
""", 1)
    (profile / "PickerView.qml").write_text(source)
    (profile / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 property int dismissals: 0
 FloatingWindow {
  visible: true; implicitWidth: 600; implicitHeight: 600
  PickerView { id: view; anchors.fill: parent; onDismissed: dismissals++ }
 }
 Timer { interval: 100; running: true
  onTriggered: {
   function check(ok, message) { if (!ok) throw new Error(message) }
   // Signal exits can carry a number also used by timeout's normal exit.
   view.busy = true
   view.testWallpaper.exited(137, 1)
   check(!view.busy && !view.error.includes("timed out") && view.error.includes("Could not set"), "Crash misreported as timeout")
   view.busy = true
   view.testWallpaper.exited(124, 0)
   check(view.error.includes("timed out"), "Timeout was lost")
   view.busy = true
   view.operationCancelled = true
   view.testWallpaper.exited(0, 0)
   check(view.error.includes("cancelled") && dismissals === 0, "Cancelled operation reported success")
   view.operationCancelled = false
   view.busy = true
   view.testWallpaper.exited(0, 0)
   check(dismissals === 1, "Successful operation did not dismiss")
   view.testApply._started = false
   view.testApply.stderrDone = false
   view.testApply.stderr.streamFinished()
   check(!view.testApply.stderrDone, "Failed spawn consumed stale collector output")
   console.log("PICKER RESULTS PASS")
   Qt.quit()
  }
 }
}
''')
    run_qml(profile, "PICKER RESULTS PASS")
    print("PASS picker crash, timeout, cancellation, success and failed-start results")
