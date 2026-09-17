import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight

    readonly property string status: {
        if (NetworkService.connectionType === "wifi") return NetworkService.signalIcon(NetworkService.signalStrength)
        if (NetworkService.connectionType === "ethernet") return "󰈀"
        return "󰤭"
    }

    property var nmAppletItem: null

    function findNmApplet() {
        // SystemTray.items is a Quickshell ObjectModel — Object.values()
        // does not iterate it. Use .values, same as Hyprland.workspaces.
        for (const item of SystemTray.items.values) {
            const id = (item.id || "").toLowerCase()
            if (id.includes("nm-applet") || id.includes("networkmanager")) {
                nmAppletItem = item
                return
            }
        }
        nmAppletItem = null
    }

    Connections {
        target: SystemTray.items
        function onValuesChanged() {
            if (!root.nmAppletItem) root.findNmApplet()
        }
    }

    Component.onCompleted: findNmApplet()

    QsMenuAnchor {
        id: menuAnchor
        menu: root.nmAppletItem ? root.nmAppletItem.menu : null
        anchor.item: root
    }

    Text {
        id: label
        text: root.status
        color: root.status === "󰤭"
            ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            : mouseArea.containsMouse
                ? Colors.surfaceFg
                : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
        font.pixelSize: 15
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Bold
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!root.nmAppletItem) root.findNmApplet()
            if (menuAnchor.menu) {
                Qt.callLater(() => menuAnchor.open())
            }
        }
    }
}
