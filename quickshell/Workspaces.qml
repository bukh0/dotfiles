import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "."

RowLayout {
    id: root
    property var screen
    // Drastically reduced spacing between the workspace items
    spacing: 4 

    readonly property var persistentIds: [1, 2, 3]
    readonly property var extraIds: {
        const ids = []
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 3 && (ws.toplevels.values.length > 0 || ws.id === Hyprland.focusedMonitor?.activeWorkspace?.id))
                ids.push(ws.id)
        }
        ids.sort((a, b) => a - b)
        return ids
    }
    readonly property var allIds: persistentIds.concat(extraIds)

    Process {
        id: switchProc
    }

    Repeater {
        model: root.allIds
        delegate: Item {
            id: wsItem
            required property int modelData
            readonly property int wsId: modelData
            readonly property var wsObject: {
                for (const ws of Hyprland.workspaces.values) {
                    if (ws.id === wsId) return ws
                }
                return null
            }
            
            property bool active: Hyprland.focusedMonitor?.activeWorkspace?.id === wsId

            // Tighter internal padding (+10 instead of +14) and a smaller minimum width (24 instead of 26)
            width: Math.max(24, wsLabel.implicitWidth + 10)
            height: 30

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                
                visible: wsItem.active || wsMa.containsMouse
                color: wsItem.active
                    ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.15)
                    : (wsMa.containsMouse ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.08) : "transparent")
            }

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: wsItem.wsId
                
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
                font.weight: Font.Bold
                
                color: Colors.primary
            }

            MouseArea {
                id: wsMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wsItem.wsObject) {
                        wsItem.wsObject.activate()
                    } else if (!switchProc.running) {
                        switchProc.command = ["hyprctl", "dispatch", "workspace", String(wsItem.wsId)]
                        switchProc.running = true
                    }
                }
            }
        }
    }
}
