import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "."

RowLayout {
    id: root
    property var screen
    spacing: 10

    readonly property var persistentIds: [1, 2, 3]

    readonly property var extraIds: {
        const ids = []
        for (const ws of Hyprland.workspaces.values) {
            // Was `ws.windows` — that property doesn't exist on HyprlandWorkspace,
            // so this always read as `undefined` and "occupied" was always false.
            // The real list of a workspace's windows is `toplevels`.
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
            property bool occupied: wsObject ? wsObject.toplevels.values.length > 0 : false
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
                text: wsItem.wsId
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
