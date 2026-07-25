import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight
    property string status: "󰤭"

    signal requestPanelOpen()

    Process {
        id: netPoll
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev | grep connected | head -1 | cut -d: -f1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t === "wifi")      status = "󰤨"
                else if (t === "ethernet") status = "󰈀"
                else                  status = "󰤭"
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: if (!netPoll.running) netPoll.running = true
    }

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
            ? Colors.error
            : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
        font.pixelSize: 15
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Bold
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Ignore the buggy nm-applet tray menu entirely
            // and just open our beautiful Control Panel instead
            root.requestPanelOpen()
        }
    }
}
