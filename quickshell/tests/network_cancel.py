"""Late connection errors must respect cancellation and output ownership."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="qs-network-cancel-") as directory:
    stage = Path(directory)
    source = (ROOT / "components/NetworkService.qml").read_text().replace("property bool nativeStatusEnabled: true", "property bool nativeStatusEnabled: false")
    # Disable background discovery; keep the actual connection process and
    # settlement callbacks, with nmcli replaced by a delayed fake command.
    source = source.replace("running: true", "running: false").replace("running: !root.nativeStatusEnabled", "running: false")
    source = source.replace("Component.onCompleted: statusPoll.running = true", "Component.onCompleted: {}")
    source = re.sub(r"    function refresh\(\) \{.*?\n    \}", "    function refresh() {}", source, flags=re.S)
    (stage / "NetworkService.qml").write_text(source)
    (stage / "qmldir").write_text("singleton NetworkService 1.0 NetworkService.qml\n")
    executable = stage / "nmcli"
    executable.write_text('#!/bin/sh\nsleep 0.2\nprintf "Error: Secrets were required, but not provided.\\n" >&2\nexit 10\n')
    executable.chmod(0o755)
    (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 id: root
 property int index: -1
 property int settled: 0
 property bool failed: false
 property var cases: [
  {password: "wrong", cancel: "owner", prompt: false},
  {password: "wrong", cancel: "other", prompt: true},
  {password: "wrong", cancel: "none", prompt: true},
  {password: "", cancel: "owner", prompt: false},
  {password: "wrong", cancel: "all", prompt: false},
  {password: "", cancel: "none", prompt: true}
 ]
 function check(ok, message) {
  if (!ok) { failed = true; console.error("FAIL case", index, message) }
 }
 Connections {
  target: NetworkService
  function onConnectionSettled() { root.settled++ }
 }
 Timer {
  interval: 600; running: true; repeat: true
  onTriggered: {
   if (root.index >= 0) {
    root.check(!NetworkService.busy, "busy state stuck")
    root.check(!NetworkService.submittingPassword, "submission hold stuck")
    root.check((NetworkService.awaitingPasswordFor === "Test wifi") === root.cases[root.index].prompt, "unexpected prompt state")
    root.check(root.settled === root.index + 1, "settlement signal missing or repeated")
   }
   root.index++
   if (root.index === root.cases.length) {
    if (!root.failed) console.log("NETWORK CANCEL PASS")
    Qt.quit(); return
   }
   NetworkService.cancelPasswordPrompt()
   root.check(NetworkService.connectToNetwork("Test wifi", root.cases[root.index].password, "screen-A"), "request rejected")
   cancelTimer.restart()
  }
 }
 Timer {
  id: cancelTimer; interval: 80
  onTriggered: {
   const mode = root.cases[root.index].cancel
   if (mode === "owner") NetworkService.cancelPasswordPrompt("screen-A")
   else if (mode === "other") NetworkService.cancelPasswordPrompt("screen-B")
   else if (mode === "all") NetworkService.cancelPasswordPrompt()
  }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory,
               PATH=directory + os.pathsep + os.environ["PATH"])
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", directory], env=env,
                            capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "NETWORK CANCEL PASS" in output and "FAIL case" not in output
