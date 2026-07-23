import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "."

RowLayout {
    id: root
    property var screen
    spacing: 10

    Repeater {
        model: Hyprland.workspaces

        delegate: Item {
            id: wsItem
            required property HyprlandWorkspace modelData
            property bool active: Hyprland.focusedMonitor?.activeWorkspace?.id === modelData.id
            property bool occupied: modelData.windows > 0

            visible: modelData.id > 0 && (modelData.id <= 5 || occupied || active)
            width: active ? 18 : 16
            height: active ? 18 : 16

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: wsItem.active
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                    : wsMa.containsMouse
                        ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.06)
                        : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                anchors.centerIn: parent
                text: wsItem.modelData.id
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Bold
                color: wsItem.active
                    ? Colors.primary
                    : wsMa.containsMouse
                        ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                        : Colors.surfaceFg
            }

            MouseArea {
                id: wsMa
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: wsItem.modelData.activate()
            }
        }
    }
}
