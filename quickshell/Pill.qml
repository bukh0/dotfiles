import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: rootPill
    default property alias content: layout.data

    property bool isActive: false
    property bool isHovered: false

    implicitHeight: 32
    implicitWidth: layout.implicitWidth + 24

    radius: height / 2.5

    readonly property color bgColor: isActive
        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
        : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, isHovered ? 0.9 : 0.85)

    readonly property color borderColorC: isActive
        ? Colors.primary
        : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)

    color: bgColor
    border.color: borderColorC
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 12
    }
}
