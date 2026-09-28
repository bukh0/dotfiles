import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "."

ColumnLayout {
    id: root
    spacing: 6
    enabled: audio !== null

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property real volume: audio ? audio.volume : 0.5
    property bool muted: audio ? audio.muted : false
    onAudioChanged: cmdDebounce.stop()

    readonly property string volIcon: {
        if (muted || slider.visualValue === 0) return "󰝟"
        if (slider.visualValue < 0.33) return "󰕿"
        if (slider.visualValue < 0.66) return "󰖀"
        return "󰕾"
    }

    function setVolume(value) {
        if (root.audio) root.audio.volume = value
    }

    Timer {
        id: cmdDebounce
        interval: 75
        property real pending: 0
        onTriggered: {
            root.setVolume(pending)
        }
    }

    SliderRow {
        id: slider
        icon: volIcon
        iconColor: muted ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4) : Colors.primary
        trackColor: muted ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4) : Colors.primary
        value: volume

        onIconTapped: {
            if (root.audio) root.audio.muted = !root.audio.muted
        }

        onDragged: val => {
            cmdDebounce.pending = val
            if (!cmdDebounce.running) cmdDebounce.start()
        }

        onCommitted: val => {
            cmdDebounce.stop()
            root.setVolume(val)
        }
    }
}
