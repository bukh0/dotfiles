import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "."

ColumnLayout {
    id: root
    property bool preferVerticalScroll: false
    spacing: 6
    enabled: audio !== null

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property real volume: audio && isFinite(audio.volume) ? Math.max(0, audio.volume) : 0
    property bool muted: audio ? audio.muted : false
    onAudioChanged: { cmdDebounce.stop(); slider.abortDrag() }

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
        preferVerticalScroll: root.preferVerticalScroll
        id: slider
        icon: volIcon
        iconColor: muted ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4) : Colors.primary
        trackColor: muted ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4) : Colors.primary
        // Keep the pointer mapping stable as writes reduce amplified volume.
        // Recalculate the range only after this gesture ends.
        property real dragMaximum: 1.5
        onIsDraggingChanged: if (isDragging) dragMaximum = Math.max(1.5, root.volume)
        maxValue: isDragging ? dragMaximum : Math.max(1.5, root.volume)
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
