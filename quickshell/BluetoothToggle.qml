import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: btRoot
    spacing: 6

    property bool btOn: false
    property string connectedName: ""
    property bool expanded: false
    property var devices: []
    property var previousConnected: null

    Process {
        id: notifyProc
        running: false
    }

    function notify(title, body) {
        if (notifyProc.running) return
        notifyProc.command = ["notify-send", "-a", "Bluetooth", "-u", "critical", title, body]
        notifyProc.running = true
    }

    Process {
        id: actionProc
        running: false
        onRunningChanged: {
            if (!running) btPoll.running = true;
        }
    }

    function runCommand(cmdArray) {
        if (actionProc.running) return;
        actionProc.command = cmdArray;
        actionProc.running = true;
    }

    Process {
        id: btPoll
        command: ["sh", "-c", "env NO_COLOR=1 bluetoothctl show | grep -q 'Powered: yes' && echo 'enabled' || echo 'disabled'; echo '==='; env NO_COLOR=1 bluetoothctl devices Paired; echo '==='; env NO_COLOR=1 bluetoothctl devices Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                const textOutput = text.replace(/\x1b\[[0-9;]*m/g, "").trim()
                const sections = textOutput.split("===")
                
                btRoot.btOn = (sections[0].trim() === "enabled")
                if (sections.length < 3) return
                
                const pairedLines = sections[1].trim().split("\n").filter(l => l.includes("Device "))
                const connLines = sections[2].trim().split("\n").filter(l => l.includes("Device "))
                
                const currConnectedMacs = connLines.map(l => l.split(" ")[1]).filter(m => m)
                let connectedNamesArr = []
                
                const newDevices = pairedLines.map(l => {
                    const parts = l.split(" ")
                    const mac = parts[1]
                    const name = parts.slice(2).join(" ").trim()
                    const isConn = currConnectedMacs.includes(mac)
                    
                    if (isConn) connectedNamesArr.push(name)
                    
                    return { mac: mac, name: name, connected: isConn }
                }).filter(d => d.mac)
                
                btRoot.connectedName = connectedNamesArr.join(", ")
                btRoot.devices = newDevices

                if (btRoot.previousConnected !== null) {
                    const prevMacs = btRoot.previousConnected
                    const added = currConnectedMacs.filter(m => !prevMacs.includes(m))
                    const removed = prevMacs.filter(m => !currConnectedMacs.includes(m))

                    added.forEach(m => {
                        const d = newDevices.find(x => x.mac === m)
                        if (d) btRoot.notify("Bluetooth Connected", d.name)
                    })
                    if (removed.length > 0) btRoot.notify("Bluetooth Disconnected", "Device disconnected")
                }
                btRoot.previousConnected = currConnectedMacs
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!btPoll.running && !actionProc.running) btPoll.running = true }
        Component.onCompleted: btPoll.running = true
    }

    function deviceIcon(name) {
        const n = name.toLowerCase()
        if (n.includes("headphone") || n.includes("earphone") || n.includes("buds")) return "󰋋"
        if (n.includes("mouse")) return "󰍽"
        if (n.includes("keyboard")) return "󰌌"
        if (n.includes("phone")) return "󰏲"
        if (n.includes("speaker")) return "󰓃"
        return "󰂯"
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 10
        color: btRoot.btOn
            ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, btRoot.expanded ? 0.25 : 0.15)
            : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.6)
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 8

            Rectangle {
                width: 32; height: 32; radius: 16
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰂯"
                    color: btRoot.btOn ? Colors.secondary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (btRoot.btOn) {
                            btRoot.runCommand(["bluetoothctl", "power", "off"])
                            btRoot.btOn = false; btRoot.expanded = false
                        } else {
                            btRoot.runCommand(["bluetoothctl", "power", "on"])
                            btRoot.btOn = true
                        }
                    }
                }
            }

            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (btRoot.btOn) btRoot.expanded = !btRoot.expanded

                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Bluetooth"
                            color: Colors.surfaceFg
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            visible: btRoot.btOn && btRoot.connectedName !== ""
                            text: btRoot.connectedName
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: btRoot.btOn
                        text: btRoot.expanded ? "󰅃" : "󰅀"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }

    ColumnLayout {
        visible: btRoot.expanded && btRoot.btOn
        Layout.fillWidth: true
        spacing: 4

        Text {
            visible: btRoot.devices.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: "No paired devices"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }

        Repeater {
            model: btRoot.devices
            delegate: Rectangle {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8
                
                // Local state flags for instant UI response without destroying the delegate
                property bool isProcessing: itemProc.running
                property bool isConnecting: false
                property bool isDisconnecting: false
                
                // Determines the visual connected state instantly
                property bool showConnected: (modelData.connected || isConnecting) && !isDisconnecting

                color: showConnected
                    ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.2)
                    : deviceMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

                Process {
                    id: itemProc
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const out = text.trim();
                            if (out.toLowerCase().includes("error") || out.toLowerCase().includes("failed")) {
                                btRoot.notify("Bluetooth Warning", out);
                            }
                        }
                    }
                    stderr: StdioCollector {
                        onStreamFinished: {
                            if (text.trim().length > 0) btRoot.notify("Bluetooth Error", text.trim());
                        }
                    }
                    onRunningChanged: {
                        if (!running) {
                            // Clear local overrides and fetch real system state
                            delegateRoot.isConnecting = false;
                            delegateRoot.isDisconnecting = false;
                            btPoll.running = true;
                        }
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: btRoot.deviceIcon(modelData.name)
                        color: delegateRoot.showConnected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: modelData.name
                        color: delegateRoot.showConnected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        // Keep visible if it's connected, or if it's processing (hourglass)
                        visible: delegateRoot.showConnected || delegateRoot.isProcessing
                        text: delegateRoot.isProcessing ? "󰔟" : "󰄬"
                        color: delegateRoot.isProcessing ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6) : Colors.secondary
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                MouseArea {
                    id: deviceMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: delegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (delegateRoot.isProcessing) return;
                        
                        let disconnecting = modelData.connected;
                        
                        if (disconnecting) {
                            delegateRoot.isDisconnecting = true;
                            // Instantly clear it from the top bar
                            btRoot.connectedName = btRoot.connectedName.split(",").map(x=>x.trim()).filter(n=>n!==modelData.name).join(", ");
                        } else {
                            delegateRoot.isConnecting = true;
                            // Instantly add it to the top bar
                            if (btRoot.connectedName === "") btRoot.connectedName = modelData.name;
                            else if (!btRoot.connectedName.includes(modelData.name)) btRoot.connectedName += ", " + modelData.name;
                        }
                        
                        itemProc.command = disconnecting
                            ? ["bluetoothctl", "disconnect", modelData.mac]
                            : ["bluetoothctl", "connect", modelData.mac];
                            
                        itemProc.running = true;
                    }
                }
            }
        }
    }
}
