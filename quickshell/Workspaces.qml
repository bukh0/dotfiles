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

            // Fixed size always — nothing here changes with state, so the
            // row's layout positions never shift and numbers stay parallel.
            width: 18
            height: 18

            Rectangle {
                anchors.centerIn: parent
                width: wsItem.active ? 18 : 16
                height: wsItem.active ? 18 : 16
                radius: width / 2
                color: wsItem.active
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                    : wsMa.containsMouse
                        ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.06)
                        : "transparent"

                Behavior on width { NumberAnimation { duration: 150 } }
                Behavior on height { NumberAnimation { duration: 150 } }
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
