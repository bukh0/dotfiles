import QtQuick
import Quickshell.Io

Item {
    width: label.implicitWidth
    height: label.implicitHeight

    property string status: "󰤭"  // disconnected icon default

    Process {
        id: netPoll
        // FIX: nmcli outputs 'connected', not 'activated'
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev | grep connected | head -1 | cut -d: -f1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t === "wifi")      status = "󰤨"   // wifi connected
                else if (t === "ethernet") status = "󰈀"  // ethernet
                else                  status = "󰤭"   // none
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: netPoll.running = true
    }

    Text {
        id: label
        text: status
        color: Colors.surfaceFg
        font.pixelSize: 15
        font.family: "JetBrainsMono Nerd Font"
    }
}
