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

    // Control panel drawer anchored to this window
    ControlPanel {
        id: controlPanel
        anchor.window: root
        anchor.rect.x: root.width - implicitWidth - 10
        anchor.rect.y: root.height + 6
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: pillRadius
        color: "#cc252b2b"
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 0

            // LEFT — Workspaces
            Workspaces { Layout.alignment: Qt.AlignVCenter }

            // CENTER — Clock
            Item { Layout.fillWidth: true }
            Clock { Layout.alignment: Qt.AlignVCenter }
            Item { Layout.fillWidth: true }

            // RIGHT — modules + control panel toggle
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                SystemTray {}
                NetworkIndicator {}
                BatteryIndicator {}
                NotificationBell {}

                // Control panel toggle button
                Item {
                    width: 22
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: controlPanel.isOpen
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                            : toggleMa.containsMouse
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰄶"
                        color: controlPanel.isOpen ? Colors.primary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    MouseArea {
                        id: toggleMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlPanel.toggle()
                    }
                }
            }
        }
    }
}
