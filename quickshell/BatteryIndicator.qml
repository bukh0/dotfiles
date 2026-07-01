import QtQuick
import QtQuick.Layouts
import Quickshell.Io

RowLayout {
    spacing: 4

    property int level: 100
    property bool charging: false

    property string battIcon: {
        if (charging) return "󰂄"
        if (level >= 90) return "󰁹"
        if (level >= 70) return "󰂁"
        if (level >= 50) return "󰁾"
        if (level >= 30) return "󰁼"
        if (level >= 10) return "󰁺"
        return "󰂃"
    }

    property color battColor: {
        if (charging) return Colors.tertiary
        if (level <= 15) return Colors.error
        return Colors.surfaceFg
    }

    Process {
        id: battLevel
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: level = parseInt(text.trim()) || 100
        }
    }

    Process {
        id: battStatus
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: charging = text.trim() === "Charging"
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            battLevel.running = true
            battStatus.running = true
        }
    }

    Text {
        text: battIcon
        color: battColor
        font.pixelSize: 15
        font.family: "JetBrainsMono Nerd Font"

        Behavior on color { ColorAnimation { duration: 300 } }
    }

    Text {
        text: level + "%"
        color: battColor
        font.pixelSize: 12
        font.family: "JetBrainsMono Nerd Font"

        Behavior on color { ColorAnimation { duration: 300 } }
    }
}
