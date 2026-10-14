"""Exercise the real power-profile exit handler without changing power settings."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / "components/SysmonService.qml").read_text()
process = source[source.index("    Process {"):source.index('    property string cpuPercent')]
process = process.replace("Quickshell.execDetached(", "root.notices.push(")
with tempfile.TemporaryDirectory(prefix="profile-exit-") as directory:
    shell = Path(directory) / "shell.qml"
    shell.write_text("""import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
 Item {
  id: root
  property var notices: []
""" + process + """
  Component.onCompleted: {
   profileProc.exited(0, 0)
   const successSilent = notices.length === 0
   profileProc.exited(1, 0)
   const failureWarned = notices.length === 1
   profileProc.exited(0, 1)
   console.log(successSilent && failureWarned && notices.length === 2 ? "PROFILE PASS" : "PROFILE FAIL")
   Qt.callLater(Qt.quit)
  }
 }
}
""")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory)
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", str(shell)], env=env,
                            capture_output=True, text=True, timeout=8)
    output = result.stdout + result.stderr
    assert "PROFILE PASS" in output and "PROFILE FAIL" not in output, output
    print("PASS: success stays silent; nonzero exit and crash status both notify")
