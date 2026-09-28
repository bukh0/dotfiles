import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

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
                root._restartDelay = Math.min(root._restartDelay * 2, 30000)
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

    component Stat: RowLayout {
        id: statRoot
        property string icon: ""
        property string value: ""
        property string tooltipText: ""
        property color textColor: Colors.surfaceFg

        Layout.minimumWidth: 0
        Layout.fillWidth: true

        spacing: 6

        Text {
            text: statRoot.icon
            color: statRoot.textColor
            font.pixelSize: 15; font.family: root.iconFont; font.weight: Font.Bold
        }
        Text {
            text: statRoot.value
            color: statRoot.textColor
            font.pixelSize: 12; font.family: root.uiFont; font.weight: Font.Bold

            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        HoverHandler { id: hoverHandler }

        ToolTip.visible: hoverHandler.hovered && statRoot.tooltipText !== ""
        ToolTip.text: statRoot.tooltipText
        ToolTip.delay: 300
        ToolTip.timeout: 2000
    }

    Stat {
        icon: "󰍛"
        value: root.cpuPercent
        tooltipText: root.tooltipCpu
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
    }
    VDivider {}

    Stat {
        icon: "󰆼"
        value: root.ramPercent
        tooltipText: root.tooltipRam
        textColor: Colors.surfaceFg
    }
    VDivider {}

    Stat {
        icon: "󰔏"
        value: root.cpuTemp
        tooltipText: root.tooltipTemp
        textColor: root.cpuHot ? "#ff8c00" : Colors.surfaceFg
    }
    VDivider {}

    Stat {
        icon: "󰁅"
        value: root.rxSpeed
        tooltipText: root.tooltipNet
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65)
    }
    Stat {
        icon: "󰁝"
        value: root.txSpeed
        tooltipText: root.tooltipNet
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65)
    }

    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: profileText
            text: root.powerProfile === "powersave" ? "󰌪" : (root.powerProfile === "performance" ? "󰓅" : "󰗑")
            color: root.powerProfile === "performance"
                ? Colors.error
                : (root.powerProfile === "powersave" ? Colors.tertiary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.9))
            font.pixelSize: 18
            font.family: root.iconFont
            font.weight: Font.Bold

            HoverHandler { id: profileHover }

            ToolTip.visible: profileHover.hovered && root.tooltipProfile !== ""
            ToolTip.text: root.tooltipProfile
            ToolTip.delay: 300
            ToolTip.timeout: 2000

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (profileProc.running) return
                    profileProc.command = ["bash", "-c", "exec \"$HOME/.scripts/toggle-performance.sh\""]
                    profileProc.running = true
                }
            }
        }
    }

    Process {
        id: profileProc
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) console.warn("power profile:", msg)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Power Profile", "--",
                    "Power profile change failed", "Exit status " + exitCode])
            }
        }
    }
}
