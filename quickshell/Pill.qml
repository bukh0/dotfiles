pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: rootPill
    default property alias content: layout.data

    // Lets callers recompute width using their own formula (e.g. Bar.qml's
    // center pill, which wants extra padding beyond the default so it
    // doesn't jitter as the clock text changes length).
    readonly property alias contentImplicitWidth: layout.implicitWidth

    property bool isActive: false
    property bool isHovered: false
    property int pillHeight: 32
    property int horizontalPadding: 24

    implicitHeight: pillHeight
    implicitWidth: layout.implicitWidth + horizontalPadding

    // Plain Items don't auto-bind width/height to their implicit* values
    // outside a Layout — without this the pill collapses to 0x0 anywhere
    // it's positioned with anchors instead of inside a Layout.
    width: implicitWidth
    height: implicitHeight

    radius: 4

    readonly property color bgColor: isActive
        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
        : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, isHovered ? 0.6 : 0.2)

    readonly property color borderColorC: isActive
        ? Colors.primary
        : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, isHovered ? 0.35 : 0.18)

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
