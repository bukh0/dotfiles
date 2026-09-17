import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real brightness: 0.5

    readonly property string brightIcon: {
        if (slider.visualValue < 0.25) return "󰃞"
        if (slider.visualValue < 0.5)  return "󰃟"
        if (slider.visualValue < 0.75) return "󰃠"
        return "󰃠"
    }

    Process {
        id: brightPoll
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",")
                if (parts.length >= 4) {
                    brightness = parseFloat(parts[3].replace("%", "")) / 100.0
                }
            }
        }
    }

    Timer {
        id: brightPollTimer
        interval: 2000
        running: !slider.isDragging
        repeat: true
        onTriggered: brightPoll.running = true
        Component.onCompleted: brightPoll.running = true
    }

    Process { id: setProc }

    Timer {
        id: cmdDebounce
        interval: 75
        property real pending: 0
        onTriggered: {
            setProc.command = ["brightnessctl", "set", Math.round(pending * 100) + "%"]
            setProc.running = true
        }
    }

    SliderRow {
        id: slider
        icon: brightIcon
        iconColor: Colors.tertiary
        trackColor: Colors.tertiary
        value: brightness
        minValue: 0.05

        onDragged: val => {
            cmdDebounce.pending = val
            if (!cmdDebounce.running) cmdDebounce.start()
        }

        onCommitted: val => {
            brightness = val
            cmdDebounce.stop()
            setProc.command = ["brightnessctl", "set", Math.round(val * 100) + "%"]
            setProc.running = true
            brightPollTimer.restart()
        }
    }
}
