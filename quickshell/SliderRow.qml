import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 10

    property string icon: ""
    property color iconColor: Colors.primary
    property color trackColor: Colors.primary
    property real value: 0.5      // committed value, 0..1
    property real minValue: 0.0

    property bool isDragging: dragMa.pressed
    property real dragValue: value
    readonly property real visualValue: isDragging ? dragValue : value

    signal dragged(real val)    // continuous while dragging — caller debounces the command
    signal committed(real val)  // fired once on release
    signal iconTapped()         // optional — e.g. mute toggle

    Text {
        text: root.icon
        color: root.iconColor
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font"

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: root.iconTapped()
        }
    }

    Item {
        Layout.fillWidth: true
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

            Rectangle {
                width: parent.width * Math.min(Math.max(root.visualValue, 0), 1)
                height: parent.height
                radius: 2
                color: root.trackColor
                Behavior on width { NumberAnimation { duration: root.isDragging ? 0 : 80 } }
            }
        }

        Rectangle {
            x: Math.min(Math.max(root.visualValue, 0), 1) * (parent.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: root.trackColor
            Behavior on x { NumberAnimation { duration: root.isDragging ? 0 : 80 } }
        }

        MouseArea {
            id: dragMa
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor

            onPressed: mouse => setValue(mouse.x / width)
            onPositionChanged: mouse => { if (pressed) setValue(mouse.x / width) }
            onReleased: mouse => {
                const v = clamp(mouse.x / width)
                root.dragValue = v
                root.value = v
                root.committed(v)
            }

            function setValue(val) {
                const v = clamp(val)
                root.dragValue = v
                root.value = v
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
        font.pixelSize: 11
        font.family: "JetBrainsMono Nerd Font"
        Layout.minimumWidth: 32
    }
}
