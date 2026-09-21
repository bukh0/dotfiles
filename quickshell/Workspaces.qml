import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "."

RowLayout {
    id: root
    property var screen
    spacing: Theme.spacingXS

    readonly property var workspaceList: Hyprland.workspaces.values

    readonly property var persistentIds: [1, 2, 3]

    // This bar's own monitor — not whichever monitor currently has focus.
    // Without this, every bar instance on a multi-monitor setup showed
    // the active workspace of the focused monitor, not its own.
    readonly property var monitor: Hyprland.monitorFor(root.screen)
    readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? -1

    readonly property var extraIds: {
        const ids = []
        const focusedWsId = root.activeWsId
        const workspaces = root.workspaceList
        for (let i = 0; i < workspaces.length; ++i) {
            const ws = workspaces[i]
            if (ws.id > 3 && (ws.toplevels.values.length > 0 || ws.id === focusedWsId))
                ids.push(ws.id)
        }
        ids.sort((a, b) => a - b)
        return ids
    }

    readonly property var allIds: persistentIds.concat(extraIds)

    function getWorkspaceById(id) {
        const workspaces = root.workspaceList
        for (let i = 0; i < workspaces.length; ++i) {
            if (workspaces[i].id === id) return workspaces[i]
        }
        return null
    }

    property var _pendingWsId: null

    Process {
        id: switchProc
        onRunningChanged: {
            if (!running && root._pendingWsId !== null) {
                const nextId = root._pendingWsId
                root._pendingWsId = null
                command = ["hyprctl", "dispatch", "workspace", String(nextId)]
                running = true
            }
        }
    }

    function switchWorkspace(id) {
        if (!switchProc.running) {
            switchProc.command = ["hyprctl", "dispatch", "workspace", String(id)]
            switchProc.running = true
        } else {
            root._pendingWsId = id
        }
    }

    Repeater {
        model: root.allIds

        delegate: Item {
            id: wsItem
            required property int modelData
            readonly property int wsId: modelData

            readonly property bool active: root.activeWsId === wsId

            width: Math.max(22, wsLabel.implicitWidth + 8)
            height: 22

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: Theme.radius

                color: active
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                    : (wsMa.containsMouse ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.08) : "transparent")
                border.color: active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6) : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: wsId
                font.pixelSize: Theme.fontSizeLG
                font.family: Theme.fontMono
                font.weight: Font.Bold
                color: Colors.primary
            }

            MouseArea {
                id: wsMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const ws = root.getWorkspaceById(wsId)
                    if (ws) {
                        ws.activate()
                    } else {
                        root.switchWorkspace(wsId)
                    }
                }
            }
        }
    }
}
