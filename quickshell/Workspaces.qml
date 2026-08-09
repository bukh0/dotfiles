import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "."

RowLayout {
    id: root
    property var screen
    spacing: 4

    // ── Centralised workspace list (reused in bindings and functions) ──
    readonly property var workspaceList: Hyprland.workspaces.values

    // ── Workspace IDs ─────────────────────────────────────────
    readonly property var persistentIds: [1, 2, 3]

    readonly property var extraIds: {
        const ids = []
        const focusedWsId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1
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

    // ── Cached active workspace ID ─────────────────────────────
    readonly property int activeWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1

    // Lightweight lookup – only called on click
    function getWorkspaceById(id) {
        const workspaces = root.workspaceList
        for (let i = 0; i < workspaces.length; ++i) {
            if (workspaces[i].id === id) return workspaces[i]
        }
        return null
    }

    Process {
        id: switchProc
    }

    // ── Indicators ─────────────────────────────────────────────
    Repeater {
        model: root.allIds

        delegate: Item {
            id: wsItem
            required property int modelData
            readonly property int wsId: modelData

            readonly property bool active: root.activeWsId === wsId

            width: Math.max(24, wsLabel.implicitWidth + 10)
            height: 30

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                visible: active || wsMa.containsMouse

                color: active
                    ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.15)
                    : (wsMa.containsMouse ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.08) : "transparent")

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: wsId
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
                    const ws = root.getWorkspaceById(wsId)
                    if (ws) {
                        ws.activate()
                    } else if (!switchProc.running) {
                        switchProc.command = ["hyprctl", "dispatch", "workspace", String(wsId)]
                        switchProc.running = true
                    }
                }
            }
        }
    }
}
