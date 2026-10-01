import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    property var screen
    property int count: NotificationDaemon.notificationModel.count
    property bool hasNotifs: count > 0

    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    implicitWidth: row.implicitWidth + Theme.spacingMD
    implicitHeight: row.implicitHeight + Theme.spacingSM
    radius: Theme.radius

    color: hover.hovered ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.1) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: NotificationDaemon.doNotDisturb
                ? "\uDB80\uDC9B"
                : root.hasNotifs ? "\uDB80\uDC9A" : "\uDB80\uDC9C"
            color: NotificationDaemon.doNotDisturb
                ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                : root.hasNotifs ? Colors.primary : Colors.surfaceFg
            font.pixelSize: Theme.fontSizeIcon
            font.family: root.iconFont

            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: root.hasNotifs && !NotificationDaemon.doNotDisturb
            text: root.count
            color: NotificationDaemon.doNotDisturb ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5) : Colors.primary
            font.pixelSize: Theme.fontSizeSM
            font.weight: Font.Bold
            font.family: root.uiFont
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                NotificationDaemon.surfaceScreen = root.screen
                NotificationDaemon.beginHoverOpen()
            } else {
                NotificationDaemon.scheduleHoverClose()
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            NotificationDaemon.surfaceScreen = root.screen
            NotificationDaemon.toggleDrawer()
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: NotificationDaemon.toggleDnd()
    }
}
