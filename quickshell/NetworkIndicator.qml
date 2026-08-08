import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight

    property string status: {
        if (NetworkService.connectionType === "wifi") return "󰤨"
        if (NetworkService.connectionType === "ethernet") return "󰈀"
        return "󰤭"
    }

    property bool hovered: false

    property var nmAppletItem: null
    function findNmApplet() {
        for (const item of SystemTray.items.values) {
            const id = (item.id || "").toLowerCase()
            if (id.includes("nm-applet") || id.includes("networkmanager"))
                return item
        }
        return null
    }
    Timer {
        interval: 3000
        running: root.nmAppletItem === null
        repeat: true
        onTriggered: root.nmAppletItem = root.findNmApplet()
    }
    Component.onCompleted: nmAppletItem = findNmApplet()

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
            : root.hovered
                ? Colors.surfaceFg
                : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
        font.pixelSize: 15
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Bold
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            if (menuAnchor.menu) menuAnchor.open()
        }
    }
}
