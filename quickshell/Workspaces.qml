import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property HyprlandWorkspace modelData
            property bool active: Hyprland.focusedMonitor?.activeWorkspace?.id === modelData.id

            width: numText.implicitWidth + 16
            height: 22
            radius: 6
            color: active
                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.9)
                : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.6)

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Text {
                id: numText
                anchors.centerIn: parent
                text: modelData.id
                color: active ? Colors.primaryFg : Colors.surfaceFg
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                font.weight: active ? Font.Bold : Font.Normal
            }

            MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
