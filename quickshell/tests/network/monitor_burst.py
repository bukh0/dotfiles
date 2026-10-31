"""A sustained NetworkManager event stream must still refresh the bar."""
from pathlib import Path
import tempfile
from harness import ROOT, run_qml

with tempfile.TemporaryDirectory(prefix="qs-network-burst-") as directory:
    stage = Path(directory)
    source = (ROOT / "components/NetworkService.qml").read_text()
    source = source.replace("running: true", "running: false")
    source = source.replace("Component.onCompleted: root.refresh()", "Component.onCompleted: {}")
    source = source.replace("id: root", """id: root
    property int testPolls: 0
    function testEvent() { nmMonitor.stdout.read("network changed") }
""", 1)
    source = source.replace("function refresh() {", "function refresh() { testPolls++; return;", 1)
    (stage / "NetworkService.qml").write_text(source)
    (stage / "qmldir").write_text("singleton NetworkService 1.0 NetworkService.qml\n")
    (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Timer { interval: 20; running: true; repeat: true
  onTriggered: NetworkService.testEvent()
 }
 Timer { interval: 450; running: true
  onTriggered: {
   if (NetworkService.testPolls < 1 || NetworkService.testPolls > 3)
    console.error("FAIL continuous events starved or flooded refreshes", NetworkService.testPolls)
   else console.log("NETWORK BURST PASS")
   Qt.quit()
  }
 }
}
''')
    run_qml(stage, "NETWORK BURST PASS")
    print("PASS bounded network monitor refresh during continuous events")
