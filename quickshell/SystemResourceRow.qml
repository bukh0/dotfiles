import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8 // Reduced spacing to fit the drawer comfortably

    // ── Fonts ──────────────────────────────────────────────
    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    // ── Display values ─────────────────────────────────────
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

    property string tempSourcePath: ""

    // ── Resolve Temp File Once ──────────────────────────────
    Process {
        id: tempSourceDiscover
        command: ["sh", "-c",
            "for i in 0 1 2 3 4 5 6 7 8 9; do f=/sys/class/thermal/thermal_zone$i/temp; " +
            "[ -r \"$f\" ] && { echo \"$f\"; exit; }; done; " +
            "ls /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.tempSourcePath = text.trim().split("\n")[0] || "none"
                sysmonDaemon.running = true
            }
        }
    }

    // ── C++ Daemon Stream ────────────────────────────────────
    Process {
        id: sysmonDaemon
        command: ["sh", "-c", "~/.config/quickshell/sysmon " + root.tempSourcePath]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|")
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
        // Auto-restart if killed
        onRunningChanged: { if (!running && root.tempSourcePath !== "") sysmonDaemon.running = true }
    }

    // ── Reusable Stat (Scalable) ──────────────────────────
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

    // ── Layout ─────────────────────────────────────────────
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

    // Expands to push the power profile toggle flush against the right wall
    Item { 
        Layout.fillWidth: true
        Layout.minimumWidth: 0 
    }

    // ── Power profile toggle ──────────────────────────────
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
                    profileProc.command = ["bash", "-c", "~/.scripts/toggle-performance.sh"]
                    profileProc.running = true
                }
            }
        }
    }

    Process {
        id: profileProc
    }
}
