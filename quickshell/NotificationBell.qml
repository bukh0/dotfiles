import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    property int count: NotificationDaemon.notifications ? NotificationDaemon.notifications.length : 0
    property bool hasNotifs: count > 0

    implicitWidth: row.implicitWidth + 12
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.hasNotifs ? "󰂚" : "󰂜"
            color: root.hasNotifs ? Colors.primary : Colors.surfaceFg
            font.pixelSize: 15
            font.family: "JetBrainsMono Nerd Font"

            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            visible: root.hasNotifs
            text: root.count
            color: Colors.primary
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: NotificationDaemon.beginHoverOpen()
        onExited: NotificationDaemon.scheduleHoverClose()
        onClicked: NotificationDaemon.toggleDrawer()
    }
}
