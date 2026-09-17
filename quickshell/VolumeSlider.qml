import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real volume: 0.5
    property bool muted: false

    readonly property string volIcon: {
        if (muted || slider.visualValue === 0) return "󰝟"
        if (slider.visualValue < 0.33) return "󰕿"
        if (slider.visualValue < 0.66) return "󰖀"
        return "󰕾"
    }

    Process {
        id: volPoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                const match = txt.match(/Volume:\s+([\d.]+)/)
                if (match) volume = parseFloat(match[1])
                muted = txt.includes("[MUTED]")
            }
        }
    }

    Timer {
        id: volPollTimer
        interval: 1000
        running: !slider.isDragging
        repeat: true
        onTriggered: volPoll.running = true
        Component.onCompleted: volPoll.running = true
    }

    Process { id: ctlProc }
    Process { id: muteProc }

    Timer {
        id: cmdDebounce
        interval: 75
        property real pending: 0
        onTriggered: {
            ctlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pending.toFixed(2)]
            ctlProc.running = true
        }
    }

    SliderRow {
        id: slider
        icon: volIcon
        iconColor: muted ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4) : Colors.primary
        trackColor: muted ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4) : Colors.primary
        value: volume

        onIconTapped: {
            muteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
            muteProc.running = true
            volPollTimer.restart()
            Qt.callLater(() => volPoll.running = true)
        }

        onDragged: val => {
            cmdDebounce.pending = val
            if (!cmdDebounce.running) cmdDebounce.start()
        }

        onCommitted: val => {
            volume = val
            cmdDebounce.stop()
            ctlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", val.toFixed(2)]
            ctlProc.running = true
            volPollTimer.restart()
        }
    }
}
