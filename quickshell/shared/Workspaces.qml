import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "."

RowLayout {
    id: root
    property var screen
    spacing: Theme.workspaceSpacing

    readonly property var workspaceList: Hyprland.workspaces.values

    readonly property var persistentIds: [1, 2, 3]

    readonly property var monitor: Hyprland.monitorFor(root.screen)
    readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? -1

    readonly property var extraIds: {
        const ids = []
        const focusedWsId = root.activeWsId
        const workspaces = root.workspaceList || []
        for (let i = 0; i < workspaces.length; ++i) {
            const ws = workspaces[i]
            const toplevels = ws.toplevels?.values || []
            if (ws.id > 3 && (toplevels.length > 0 || ws.id === focusedWsId))
                ids.push(ws.id)
        }
        ids.sort((a, b) => a - b)
        return ids
    }

    // Stored (not computed inline) so the Repeater's model only gets a new
    // array reference — and rebuilds its delegates — when the actual set
    // of workspace ids changes, not on every Hyprland toplevel event
    // anywhere, which recomputes extraIds with a new object even when its
    // contents are identical to before.
    property var allIds: persistentIds.concat(extraIds)

    function _sameIds(a, b) {
        if (!a || !b) return false
        if (a.length !== b.length) return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false
        }
        return true
    }

    onExtraIdsChanged: {
        const next = persistentIds.concat(extraIds)
        if (!root._sameIds(next, root.allIds)) root.allIds = next
    }

    function getWorkspaceById(id) {
        const workspaces = root.workspaceList || []
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

            width: Math.max(Theme.workspaceMinWidth, wsLabel.implicitWidth + Theme.workspaceHorizontalPadding)
            height: Theme.workspaceHeight

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: Theme.workspaceRadius
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
                font.pixelSize: Theme.workspaceFontSize
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
