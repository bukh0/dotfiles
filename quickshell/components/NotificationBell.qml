import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    property alias hitArea: hitItem
    property bool barVisible: true
    onBarVisibleChanged: if (!barVisible) NotificationDaemon.setTriggerHovered(root, false)
    property real hoverBottomMargin: 0
    property var screen
    property int count: NotificationDaemon.notificationModel.count
    property bool hasNotifs: count > 0

    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono
    onVisibleChanged: if (!visible) NotificationDaemon.setTriggerHovered(root, false)
    Component.onDestruction: NotificationDaemon.setTriggerHovered(root, false)

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

    // Extend the trigger through the bar's bottom margin. The drawer starts
    // immediately below the bar, so no surface overlap or proxy click is needed.
    Item {
        id: hitItem
        enabled: root.visible && root.barVisible
        anchors.fill: parent
        anchors.bottomMargin: -root.hoverBottomMargin
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                NotificationDaemon.setTriggerHovered(root, hovered && root.visible && root.barVisible)
                if (root.visible && root.barVisible && hovered && !NotificationDaemon.drawerPinned) {
                    NotificationDaemon.surfaceScreen = root.screen
                    NotificationDaemon.beginHoverOpen()
                }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (!(NotificationDaemon.isDrawerOpen && NotificationDaemon.drawerPinned))
                    NotificationDaemon.surfaceScreen = root.screen
                NotificationDaemon.toggleDrawer()
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: NotificationDaemon.toggleDnd()
        }
    }
}
