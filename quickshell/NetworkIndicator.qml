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
        onTriggered: netPoll.running = true
    }

    property var nmAppletItem: {
        for (const item of SystemTray.items.values) {
            if ((item.id || "").toLowerCase() === "nm-applet")
                return item
        }
        return null
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.nmAppletItem ? root.nmAppletItem.menu : null
        anchor.item: root
    }

    Text {
        id: label // Added missing ID so the root item has a valid width/height
        text: root.status // Changed to actually use the network status icon
        
        // Optional: Make it error-colored if disconnected, otherwise standard color
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
            if (menuAnchor.menu)
                menuAnchor.open()
        }
    }
}
