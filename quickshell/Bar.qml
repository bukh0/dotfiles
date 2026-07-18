import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: root
    property var screen

    property int barHeight: 34
    property int sidePadding: 10
    property int topPadding: 6
    property int pillRadius: 12

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: barHeight + topPadding * 2
    exclusiveZone: barHeight + topPadding * 2
    color: "transparent"

    margins {
        top: topPadding
        left: sidePadding
        right: sidePadding
    }

    // Control panel fullscreen overlay
    ControlPanel {
        id: controlPanel
        screen: root.screen
    }

    // Notification drawer fullscreen overlay
    NotificationDrawer {
        id: notifDrawer
        screen: root.screen
    }

    // Notification toast anchored to the right
    NotificationPopup {
        id: notifPopup
        anchor.window: root
        anchor.rect.x: root.width - implicitWidth - 10
        anchor.rect.y: root.height + 6
    }

    Connections {
        target: NotificationDaemon
        function onNewNotification(data) {
            notifPopup.showNotification(data)
        }
    }

    Item {
        anchors.fill: parent

        // LEFT PILL — Workspaces
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            height: root.barHeight
            width: leftLayout.implicitWidth + 28
            radius: root.pillRadius
            color: "#cc252b2b"
            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35)
            border.width: 1

            RowLayout {
                id: leftLayout
                anchors.centerIn: parent
                spacing: 0
                Workspaces { screen: root.screen }
            }
        }

        // CENTER PILL — Clock & Control Panel Toggle
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            height: root.barHeight
            width: centerLayout.implicitWidth + 28
            radius: root.pillRadius
            border.width: 1

            color: controlPanel.isOpen 
                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                : centerMa.containsMouse
                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.1)
                : "#cc252b2b"
            
            border.color: controlPanel.isOpen
                ? Colors.primary
                : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35)
            
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: centerLayout
                anchors.centerIn: parent
                Clock {}
            }

            MouseArea {
                id: centerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controlPanel.isOpen = !controlPanel.isOpen
            }
        }

        // RIGHT PILL — System modules
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.barHeight
            width: rightLayout.implicitWidth + 28
            radius: root.pillRadius
            color: "#cc252b2b"
            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35)
            border.width: 1

            RowLayout {
                id: rightLayout
                anchors.centerIn: parent
                spacing: 10

                SystemTray {}
                NetworkIndicator {}
                BatteryIndicator {}
                NotificationBell {}
            }
        }
    }
}
