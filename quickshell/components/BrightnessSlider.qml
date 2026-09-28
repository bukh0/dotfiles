import QtQuick
import QtQuick.Layouts
import "."

// UI only. Discovery, syncing and writing live in BrightnessService.
ColumnLayout {
    id: root
    spacing: 6

    // Known at startup, so the row is there from the first frame of the
    // panel opening instead of popping in afterwards.
    visible: BrightnessService.available
    property bool _interacting: false

    readonly property string brightIcon: {
        if (slider.visualValue < 0.25) return "󰃞"
        if (slider.visualValue < 0.5)  return "󰃟"
        if (slider.visualValue < 0.75) return "󰃠"
        return "󰃡"
    }

    // Tell the service the panel is open (enables the poll + fresh read).
    Component.onCompleted: BrightnessService.watchers++
    Component.onDestruction: {
        BrightnessService.watchers--
        if (_interacting) BrightnessService.interactions--
    }

    SliderRow {
        id: slider
        icon: root.brightIcon
        iconColor: Colors.tertiary
        trackColor: Colors.tertiary
        value: BrightnessService.brightness
        minValue: BrightnessService.minimum

        onIsDraggingChanged: {
            if (root._interacting === isDragging) return
            root._interacting = isDragging
            BrightnessService.interactions += isDragging ? 1 : -1
        }

        onDragged: val => BrightnessService.request(val)
        onCommitted: val => BrightnessService.request(val)
    }
}
