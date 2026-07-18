import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: root
    spacing: 6

    property bool wifiOn: false
    property string ssid: ""
    property bool expanded: false
    property var networks: []
    property bool scanning: false

    property var cmdProc: Process {
        id: cmdProc
        running: false
        // Wait until nmcli actually finishes connecting before re-polling
        onRunningChanged: {
            if (!running) {
                wifiPoll.running = true
                if (expanded) scan()
            }
        }
    }

    function runCommand(cmd) {
        if (cmdProc.running) return
        cmdProc.command = cmd
        cmdProc.running = true
    }

    Process {
        id: wifiPoll
        command: ["sh", "-c", "nmcli radio wifi && nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2 | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                wifiOn = lines[0]?.trim() === "enabled"
                ssid = lines[1]?.trim() || ""
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!cmdProc.running) wifiPoll.running = true }
        Component.onCompleted: wifiPoll.running = true
    }

    Process {
        id: scanPoll
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE dev wifi list | head -20"]
        stdout: StdioCollector {
            onStreamFinished: {
                scanning = false
                const lines = text.trim().split("\n").filter(l => l.trim() !== "")
                const seen = {}
                const parsed = []
                for (const line of lines) {
                    const parts = line.split(":")
                    if (parts.length < 4) continue
                    const name = parts[0]
                    if (!name || seen[name]) continue
                    seen[name] = true
                    parsed.push({
                        ssid: name,
                        signal: parseInt(parts[1]) || 0,
                        security: parts[2] !== "--",
                        active: parts[3] === "yes"
                    })
                }
                parsed.sort((a, b) => b.signal - a.signal)
                networks = parsed
            }
        }
    }

    function scan() {
        scanning = true
        networks = []
        scanPoll.running = true
    }

    function signalIcon(sig) {
        if (sig >= 75) return "󰤨"
        if (sig >= 50) return "󰤥"
        if (sig >= 25) return "󰤢"
        return "󰤟"
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 10
        color: wifiOn
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, expanded ? 0.25 : 0.15)
            : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.6)
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 8

            Text {
                text: wifiOn ? "󰤨" : "󰤭"
                color: wifiOn ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Wi-Fi"
                    color: Colors.surfaceFg
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    visible: wifiOn && ssid !== ""
                    text: ssid
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: wifiOn
                text: expanded ? "󰅃" : "󰅀"
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!wifiOn) {
                    root.runCommand(["nmcli", "radio", "wifi", "on"])
                    wifiOn = true // Optimistic update
                } else {
                    expanded = !expanded
                    if (expanded) scan()
                }
            }
        }
    }

    ColumnLayout {
        visible: expanded && wifiOn
        Layout.fillWidth: true
        spacing: 4

        Text {
            visible: scanning
            Layout.alignment: Qt.AlignHCenter
            text: "Scanning..."
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }

        Repeater {
            model: networks

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8
                color: modelData.active
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                    : networkMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: signalIcon(modelData.signal)
                        color: modelData.active ? Colors.primary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                        text: modelData.ssid
                        color: modelData.active ? Colors.primary : Colors.surfaceFg
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: modelData.security
                        text: "󰌾"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                        visible: modelData.active
                        text: "󰄬"
                        color: Colors.primary
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                MouseArea {
                    id: networkMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let cmd = modelData.active
                            ? ["sh", "-c", "nmcli dev disconnect \"$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -1)\""]
                            : ["nmcli", "dev", "wifi", "connect", modelData.ssid]
                            
                        // Optimistic UI updates (ES5 compatible for QML)
                        let newState = !modelData.active
                        let newNetworks = []
                        for (let i = 0; i < root.networks.length; i++) {
                            let n = root.networks[i]
                            newNetworks.push({
                                ssid: n.ssid,
                                signal: n.signal,
                                security: n.security,
                                active: n.ssid === modelData.ssid ? newState : false
                            })
                        }
                        root.networks = newNetworks
                        if (newState) root.ssid = modelData.ssid
                        
                        root.runCommand(cmd)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 8
            color: rescanMa.containsMouse
                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰑐  Rescan"
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }

            MouseArea {
                id: rescanMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: scan()
            }
        }
    }
}
