import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: Theme.indicatorGap

    property string icon: ""
    property color iconColor: Colors.primary
    property color trackColor: Colors.primary
    property real value: 0.5
    property real minValue: 0.0

    // Own the interaction lifetime: MouseArea.pressed becomes false before
    // released is delivered, which otherwise briefly restores the old value.
    property bool isDragging: false
    property real dragValue: value
    readonly property real visualValue: isDragging ? dragValue : value

    signal dragged(real val)
    signal committed(real val)
    signal iconTapped()

    Text {
        text: root.icon
        color: root.iconColor
        font.pixelSize: Theme.indicatorIconSize
        font.family: Theme.fontMono

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: root.iconTapped()
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: Theme.sliderThumbSize + 14

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.sliderTrackHeight
            radius: height / 2
            color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

            Rectangle {
                width: Theme.sliderThumbSize / 2 + (parent.width - Theme.sliderThumbSize) * Math.min(Math.max(root.visualValue, 0), 1)
                height: parent.height
                radius: height / 2
                color: root.trackColor
                Behavior on width { NumberAnimation { duration: root.isDragging ? 0 : 80 } }
            }
        }

        Rectangle {
            x: Math.min(Math.max(root.visualValue, 0), 1) * (parent.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.sliderThumbSize
            height: Theme.sliderThumbSize
            radius: width / 2
            color: root.trackColor
            Behavior on x { NumberAnimation { duration: root.isDragging ? 0 : 80 } }
        }

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y / 1000 : event.angleDelta.y / 120 * 0.05
                if (delta === 0 || root.isDragging) { event.accepted = false; return }
                const value = Math.max(root.minValue, Math.min(1, root.visualValue + delta))
                root.dragged(value)
                root.committed(value)
                event.accepted = true
            }
        }
        MouseArea {
            id: dragMa
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor

            onPressed: mouse => {
                root.dragValue = valueAt(mouse.x)
                root.isDragging = true
                setValue(root.dragValue)
            }
            onPositionChanged: mouse => { if (pressed) setValue(valueAt(mouse.x)) }
            onReleased: mouse => {
                const v = valueAt(mouse.x)
                root.dragValue = v
                root.committed(v)
                root.isDragging = false
            }
            onCanceled: {
                root.committed(root.dragValue)
                root.isDragging = false
            }

            function valueAt(x) {
                return clamp((x - Theme.sliderThumbSize / 2) / Math.max(1, width - Theme.sliderThumbSize))
            }

            function setValue(val) {
                const v = clamp(val)
                root.dragValue = v
                root.dragged(v)
            }

            function clamp(v) {
                return Math.max(root.minValue, Math.min(1, v))
            }
        }
    }

    Text {
        text: Math.round(root.visualValue * 100) + "%"
        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
        font.pixelSize: Theme.fontSizeSM
        font.family: Theme.fontMono
        // Keep the track stationary when the label changes to/from 100%.
        Layout.preferredWidth: percentMetrics.width
        horizontalAlignment: Text.AlignRight
    }

    TextMetrics {
        id: percentMetrics
        text: "100%"
        font.pixelSize: Theme.fontSizeSM
        font.family: Theme.fontMono
    }
}
