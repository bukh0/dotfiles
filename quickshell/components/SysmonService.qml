pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    function initialize() {} // Accessed once by the shell to start sampling.
    function togglePowerProfile() {
        if (!profileProc.running) profileProc.running = true
    }

    // Keep authentication and the toggle alive when the panel unloads.
    Process {
        id: profileProc
        command: ["bash", Quickshell.shellPath("../../native/toggle-performance.sh")]
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) console.warn("power profile:", msg)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Power Profile", "--",
                    "Power profile change failed", "Authentication was cancelled or the profile could not be applied."])
            }
        }
    }

    property string cpuPercent: "0%"
    property string ramPercent: "0%"
    property string rxSpeed: "0 B/s"
    property string txSpeed: "0 B/s"
    property string powerProfile: "auto"
    property string cpuTemp: "--°C"
    property bool   cpuHot: false

    property string tooltipRam: ""
    property string tooltipCpu: ""
    property string tooltipNet: "Calculating…"
    property string tooltipTemp: "Calculating…"
    property string tooltipProfile: ""

    property string tempSourcePath: "none"
    property bool _restartForTemperature: false
    property int _restartDelay: 250

    Process {
        id: tempSourceDiscover
        command: ["sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*; do " +
            "[ -r \"$z/type\" ] && case \"$(cat \"$z/type\")\" in " +
            "x86_pkg_temp|cpu*|k10temp*) echo \"$z/temp\"; exit;; esac; " +
            "done; " +
            "for h in /sys/class/hwmon/hwmon*; do " +
            "case \"$(cat \"$h/name\" 2>/dev/null)\" in coretemp|k10temp) " +
            "[ -r \"$h/temp1_input\" ] && echo \"$h/temp1_input\"; exit;; esac; " +
            "done"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const discovered = text.trim().split("\n")[0] || "none"
                if (discovered === root.tempSourcePath && sysmonDaemon.running) return
                root.tempSourcePath = discovered
                if (sysmonDaemon.running) {
                    root._restartForTemperature = true
                    sysmonDaemon.running = false
                } else {
                    sysmonRestart.restart()
                }
            }
        }
    }

    Timer {
        id: sysmonStableTimer
        interval: 5000
        onTriggered: root._restartDelay = 250
    }

    Process {
        id: sysmonDaemon
        command: [Theme.sysmonPath, root.tempSourcePath]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("\u001f")
                if (parts.length >= 11) {
                    root.ramPercent   = parts[0]
                    root.tooltipRam   = parts[1].replace(/\\n/g, "\n")
                    root.cpuPercent   = parts[2]
                    root.tooltipCpu   = parts[3].replace(/\\n/g, "\n")
                    root.rxSpeed      = parts[4]
                    root.txSpeed      = parts[5]
                    root.tooltipNet   = parts[6].replace(/\\n/g, "\n")
                    root.cpuTemp      = parts[7]
                    root.cpuHot       = parts[8] === "1"
                    root.tooltipTemp  = parts[9].replace(/\\n/g, "\n")
                    root.powerProfile = parts[10]
                    root.tooltipProfile = `Power Profile: ${parts[10]}`
                }
            }
        }
        onRunningChanged: {
            if (running) {
                sysmonStableTimer.restart()
                return
            }
            sysmonStableTimer.stop()
            if (root.tempSourcePath !== "") {
                if (!root._restartForTemperature) root._restartDelay = Math.min(root._restartDelay * 2, 30000)
                sysmonRestart.interval = root._restartDelay
                sysmonRestart.restart()
            }
        }
    }

    Timer {
        id: sysmonRestart
        interval: 250
        onTriggered: {
            root._restartForTemperature = false
            sysmonDaemon.running = true
        }
    }

}
