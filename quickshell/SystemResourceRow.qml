import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    property string uiFont: "sans-serif"
    property string iconFont: "JetBrainsMono Nerd Font"

    property string cpuPercent: "0%"
    property string ramPercent: "0%"
    property string rxSpeed: "0 B/s"
    property string txSpeed: "0 B/s"
    property string powerProfile: "auto"

    property real lastIdle: 0
    property real lastTotal: 0
    property real lastRx: 0
    property real lastTx: 0

    function formatSpeed(bytes) {
        if (bytes < 1024) return bytes + " B/s"
        if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " K/s"
        return (bytes / 1048576).toFixed(1) + " M/s"
    }

    Process {
        id: statsPoll
        // Replaced && with ; and added echo wrapper for perf-mode to ensure a newline
        command: [
            "bash", 
            "-c", 
            "free | grep Mem | awk '{print int($3/$2 * 100)}'; " +
            "cat /sys/class/net/[ew]*/statistics/rx_bytes 2>/dev/null | awk '{s+=$1} END {print s+0}'; " +
            "cat /sys/class/net/[ew]*/statistics/tx_bytes 2>/dev/null | awk '{s+=$1} END {print s+0}'; " +
            "echo \"$(cat ~/.cache/perf-mode 2>/dev/null || echo 'auto')\"; " +
            "cat /proc/stat | grep '^cpu '"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length < 5) return

                root.ramPercent = lines[0] + "%"

                let currentRx = parseInt(lines[1]) || 0
                let currentTx = parseInt(lines[2]) || 0

                if (root.lastRx > 0) {
                    // Added Math.max to prevent negative spikes on network restart
                    root.rxSpeed = root.formatSpeed(Math.max(0, currentRx - root.lastRx) / 2)
                    root.txSpeed = root.formatSpeed(Math.max(0, currentTx - root.lastTx) / 2)
                }
                root.lastRx = currentRx
                root.lastTx = currentTx

                root.powerProfile = lines[3]

                const cpuParts = lines[4].split(/\s+/).slice(1).map(Number)
                const idle = cpuParts[3]
                const total = cpuParts.reduce((a, b) => a + b, 0)
                
                if (root.lastTotal > 0) {
                    const diffIdle = idle - root.lastIdle
                    const diffTotal = total - root.lastTotal
                    // Guard against division by zero 
                    const usage = diffTotal > 0 ? Math.round(100 * (1 - diffIdle / diffTotal)) : 0
                    root.cpuPercent = usage + "%"
                }
                root.lastIdle = idle
                root.lastTotal = total
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: statsPoll.running = true
        Component.onCompleted: statsPoll.running = true
    }

    Process {
        id: profileProc
        onRunningChanged: {
            if (!running) statsPoll.running = true
        }
    }

    component Stat: RowLayout {
        id: statRoot // Added explicit ID for scoping
        property string icon: ""
        property string value: ""
        property color textColor: Colors.surfaceFg
        spacing: 6
        Text { text: statRoot.icon; color: statRoot.textColor; font.pixelSize: 15; font.family: root.iconFont; font.weight: Font.Bold }
        Text { text: statRoot.value; color: statRoot.textColor; font.pixelSize: 12; font.family: root.uiFont; font.weight: Font.Bold }
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
    }

    Stat { icon: "󰍛"; value: root.cpuPercent; textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8) }
    Divider {}
    Stat { icon: "󰘚"; value: root.ramPercent; textColor: Colors.surfaceFg }
    Divider {}
    Stat { icon: "󰁅"; value: root.rxSpeed; textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65) }
    Stat { icon: "󰁝"; value: root.txSpeed; textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65) }

    Item { Layout.fillWidth: true }

    Text {
        text: root.powerProfile === "powersave" ? "󰌪" : (root.powerProfile === "performance" ? "󰓅" : "󰗑")
        color: root.powerProfile === "performance"
            ? Colors.error
            : (root.powerProfile === "powersave" ? Colors.tertiary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.9))
        font.pixelSize: 18
        font.family: root.iconFont
        font.weight: Font.Bold

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (profileProc.running) return
                profileProc.command = ["bash", "-c", "~/.scripts/toggle-performance.sh"]
                profileProc.running = true
            }
        }
    }
}
