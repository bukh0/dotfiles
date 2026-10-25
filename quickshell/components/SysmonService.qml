pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    property int watchers: 0
    property bool sampling: false
    property bool _skipFirst: true
    property bool _stoppingForIdle: false
    onWatchersChanged: {
        if (watchers > 0) {
            if (root.tempSourcePath === "none" && !tempSourceDiscover.running)
                tempSourceDiscover.running = true
            if (!sysmonDaemon.running) sysmonRestart.restart()
        } else {
            sysmonRestart.stop()
            startupCheck.stop()
            sysmonStableTimer.stop()
            root._restartForTemperature = false
            root._stoppingForIdle = sysmonDaemon.running
            sysmonDaemon.running = false
        }
    }
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
            // The wrapper reserves normal exit 130 for dialog cancellation.
            if (exitStatus === 0 && exitCode === 130) return
            if (exitCode !== 0 || exitStatus !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Power Profile", "--",
                    "Power profile change failed", "The profile could not be applied."])
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
    property string tooltipCpu: "Calculating…"
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
                if (discovered === root.tempSourcePath && (sysmonDaemon.running || sysmonRestart.running)) return
                root.tempSourcePath = discovered
                if (sysmonDaemon.running) {
                    root._restartForTemperature = true
                    sysmonDaemon.running = false
                } else if (root.watchers > 0) {
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
                    root.ramPercent = parts[0]
                    root.tooltipRam = parts[1].replace(/\\n/g, "\n")
                    root.cpuTemp = parts[7]
                    root.cpuHot = parts[8] === "1"
                    root.tooltipTemp = parts[9].replace(/\\n/g, "\n")
                    root.powerProfile = parts[10]
                    root.tooltipProfile = `Power Profile: ${parts[10]}`
                    // Only delta metrics need a full measurement interval.
                    if (root._skipFirst) { root._skipFirst = false; return }
                    root.cpuPercent = parts[2]
                    root.tooltipCpu = parts[3].replace(/\\n/g, "\n")
                    root.rxSpeed = parts[4]
                    root.txSpeed = parts[5]
                    root.tooltipNet = parts[6].replace(/\\n/g, "\n")
                }
            }
        }
        onStarted: {
            root._stoppingForIdle = false
            root._skipFirst = true
            root.sampling = true
            startupCheck.stop()
            sysmonStableTimer.restart()
        }
        onExited: {
            root.sampling = false
            root._scheduleRestart()
        }
    }


    function _scheduleRestart() {
        startupCheck.stop()
        sysmonStableTimer.stop()
        const intentional = root._stoppingForIdle || root._restartForTemperature
        root._stoppingForIdle = false
        root._restartForTemperature = false
        if (root.watchers <= 0 || sysmonRestart.running) return
        if (!intentional)
            root._restartDelay = Math.min(root._restartDelay * 2, 30000)
        sysmonRestart.interval = root._restartDelay
        sysmonRestart.restart()
    }

    Timer {
        id: startupCheck
        interval: 500
        onTriggered: {
            if (!sysmonDaemon.running) {
                console.warn("sysmon: failed to start", Theme.sysmonPath, "; retrying with backoff")
                root._scheduleRestart()
            }
        }
    }

    Timer {
        id: sysmonRestart
        interval: 250
        onTriggered: {
            if (root.watchers <= 0) return
            root._restartForTemperature = false
            startupCheck.restart()
            sysmonDaemon.running = true
        }
    }

}
