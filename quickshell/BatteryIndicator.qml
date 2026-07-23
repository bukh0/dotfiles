import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight

    property int capacity: 100
    property string status: "Unknown"

    readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    readonly property bool isCharging: status === "Charging" || status === "Full" || status === "Not charging"
    readonly property bool isCritical: !isCharging && capacity <= 10
    readonly property bool isLow: !isCharging && capacity <= 20

    readonly property string icon: {
        if (status === "Charging") return "󰂄"
        if (status === "Full" || status === "Not charging") return "󰚥"
        const idx = Math.min(9, Math.max(0, Math.floor(capacity / 10)))
        return icons[idx]
    }

    readonly property color iconColor: {
        if (isCharging) return Colors.primary
        if (isCritical) return Colors.error
        if (isLow) return Colors.tertiary
        return Colors.surfaceFg
    }

    Process {
        id: battPoll
        // Changed && to ; just in case the capacity read fails on weird hardware
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 ; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length >= 2) {
                    root.capacity = parseInt(lines[0]) || 0
                    root.status = lines[1].trim()
                }
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: battPoll.running = true
    }

    SequentialAnimation {
        running: root.isCritical
        loops: Animation.Infinite
        NumberAnimation { target: label; property: "opacity"; to: 0.3; duration: 500 }
        NumberAnimation { target: label; property: "opacity"; to: 1.0; duration: 500 }
        // Reset opacity when plugged in to prevent getting stuck at 0.3
        onStopped: label.opacity = 1.0 
    }

    Text {
        id: label
        text: root.icon + " " + root.capacity + "%"
        color: root.iconColor
        font.pixelSize: 13
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Bold

        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
