"""Recover from repeated missing sysmon launches using the real process lifecycle."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="qs-sysmon-launch-") as directory:
    stage = Path(directory)
    (stage / "SysmonService.qml").write_text((ROOT / "components/SysmonService.qml").read_text())
    (stage / "qmldir").write_text("singleton SysmonService 1.0 SysmonService.qml\nsingleton Theme 1.0 Theme.qml\n")
    (stage / "Theme.qml").write_text('''pragma Singleton
import QtQuick
QtObject { property string sysmonPath: "/nonexistent/qs-sysmon-test" }
''')
    mock = stage / "sysmon"
    baseline = "50%\x1fRAM\x1f0%\x1fCPU\x1f0 B/s\x1f0 B/s\x1fNet\x1f45°C\x1f0\x1fTemp\x1fauto"
    measured = "50%\x1fRAM\x1f37%\x1fCPU\x1f1 B/s\x1f2 B/s\x1fNet\x1f45°C\x1f0\x1fTemp\x1fauto"
    mock.write_text("#!/bin/sh\nprintf '%s\\n' '" + baseline + "'\nsleep 0.4\nprintf '%s\\n' '" + measured + "'\nexec sleep 10\n")
    mock.chmod(0o755)
    (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
ShellRoot {
 Component.onCompleted: {
  SysmonService.cpuPercent = "61%"
  SysmonService.rxSpeed = "9 B/s"
  SysmonService.watchers++
 }
 Connections {
  target: SysmonService
  function onCpuPercentChanged() {
   if (SysmonService.cpuPercent === "0%") { console.log("FAIL baseline overwrote cached CPU"); Qt.quit() }
  }
  function onRxSpeedChanged() {
   if (SysmonService.rxSpeed === "0 B/s") { console.log("FAIL baseline overwrote cached network rate"); Qt.quit() }
  }
 }
 Timer {
  interval: 100; running: true; repeat: true
  property bool restored: false
  property int idleTicks: 0
  property int phase: 0
  property bool sawImmediate: false
  onTriggered: {
   if (!restored && SysmonService._restartDelay >= 1000) {
    restored = true
    Theme.sysmonPath = "''' + str(mock) + '''"
   }
   if (phase === 0 && restored && SysmonService.cpuPercent === "61%" && SysmonService.ramPercent === "50%") {
    if (SysmonService.cpuTemp !== "45°C" || SysmonService.powerProfile !== "auto") {
     console.log("FAIL instantaneous sample missing"); Qt.quit(); return
    }
    sawImmediate = true
   }
   if (phase === 0 && restored && SysmonService.cpuPercent === "37%") {
    if (!sawImmediate) { console.log("FAIL instantaneous values delayed until delta sample"); Qt.quit(); return }
    SysmonService._restartForTemperature = true
    SysmonService.watchers = 0
    if (SysmonService._restartForTemperature) { console.log("FAIL idle retained restart intent"); Qt.quit(); return }
    SysmonService._restartForTemperature = true
    SysmonService._scheduleRestart()
    if (SysmonService._restartForTemperature) { console.log("FAIL exit retained restart intent"); Qt.quit(); return }
    phase = 1
   } else if (phase === 1 && ++idleTicks >= 6) {
    if (SysmonService.sampling || SysmonService.cpuPercent !== "37%") {
     console.log("FAIL idle sampling or lost cached sample"); Qt.quit(); return
    }
    SysmonService.watchers = 2
    phase = 2
   } else if (phase === 2 && SysmonService.sampling) {
    SysmonService.watchers--
    phase = 3
   } else if (phase === 3) {
    if (!SysmonService.sampling) console.log("FAIL remaining watcher lost sampling")
    else console.log("SYSMON RECOVERY PASS")
    SysmonService.watchers = 0
    Qt.quit()
   }
  }
 }
 Timer { interval: 8000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
''')
    result = subprocess.run(["quickshell", "-p", str(stage)], capture_output=True, text=True,
                            env=dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory), timeout=12)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "SYSMON RECOVERY PASS" in output and "FAIL " not in output
    assert output.count("sysmon: failed to start") >= 2
    assert "Unable to assign" not in output and "ReferenceError" not in output
