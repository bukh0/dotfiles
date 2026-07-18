import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "."

RowLayout {
    id: root
    property var screen // Added this property declaration to fix the error
    spacing: 8

    // Ask Hyprland to update our lastIpcObject whenever a window state changes
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow") {
                Hyprland.refreshWorkspaces()
            }
        }
    }

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            visible: modelData.id > 0
            
            width: 28
            height: 28
            radius: 14
            color: modelData.active 
                ? Colors.primary 
                : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: modelData.id
                color: modelData.active ? Colors.surfaceBg : Colors.surfaceFg
                font.pixelSize: 13
                font.family: "JetBrainsMono Nerd Font"
                font.weight: modelData.active ? Font.Bold : Font.Medium
            }

            Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Show the dot if the workspace is inactive but has windows on it
                visible: !modelData.active && modelData.lastIpcObject && modelData.lastIpcObject.windows > 0
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hyprland.dispatch("workspace " + modelData.id)
                }
            }
        }
    }
}
