import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: wifiRoot
    spacing: 6

    property bool wifiOn: false
    property string ssid: ""
    property bool expanded: false
    property var networks: []
    property bool scanning: false
    
    // Helps other delegates know to uncheck themselves when a new network is clicked
    property string targetSsid: ""

    Process {
        id: notifyProc
        running: false
    }

    function notify(title, body) {
        if (notifyProc.running) return
        notifyProc.command = ["notify-send", "-a", "Network", "-u", "critical", title, body]
        notifyProc.running = true
    }

    // Global process for power toggling and rescanning
    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out.toLowerCase().includes("error")) wifiRoot.notify("Wi-Fi Warning", out);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) wifiRoot.notify("Wi-Fi Error", text.trim());
            }
        }
        onRunningChanged: {
            if (!running) wifiPoll.running = true;
        }
    }

    function runCommand(cmdArray) {
        if (actionProc.running) return;
        actionProc.command = cmdArray;
        actionProc.running = true;
    }

    Process {
        id: wifiPoll
        command: ["sh", "-c", "echo $(nmcli radio wifi); nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2- | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                wifiRoot.wifiOn = (lines[0] || "").trim() === "enabled"
                wifiRoot.ssid = (lines[1] || "").trim()
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!wifiPoll.running && !actionProc.running) wifiPoll.running = true }
        Component.onCompleted: wifiPoll.running = true
    }

    Process {
        id: scanPoll
        // ACTIVE is first to prevent shifting if SSID contains colons
        command: ["sh", "-c", "nmcli -c no -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list | head -20"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiRoot.scanning = false
                const lines = text.trim().split("\n").filter(l => l.trim() !== "")
                const parsedMap = {}
                
                for (const line of lines) {
                    const parts = line.split(":")
                    if (parts.length < 4) continue
                    
                    // Bulletproof parsing: read first and last items explicitly
                    const isActive = parts[0] === "yes"
                    const security = parts[parts.length - 1] !== "--"
                    const signal = parseInt(parts[parts.length - 2]) || 0
                    const name = parts.slice(1, parts.length - 2).join(":")
                    
                    if (!name) continue

                    if (!parsedMap[name]) {
                        parsedMap[name] = { ssid: name, signal: signal, security: security, active: isActive }
                    } else {
                        // Merge multi-band routers (2.4/5GHz) correctly
                        if (isActive) parsedMap[name].active = true;
                        if (signal > parsedMap[name].signal) parsedMap[name].signal = signal;
                    }
                }
                const parsed = Object.values(parsedMap)
                
                // Always sort the connected network to the top
                parsed.sort((a, b) => {
                    if (a.active) return -1;
                    if (b.active) return 1;
                    return b.signal - a.signal;
                })
                wifiRoot.networks = parsed
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
        color: wifiRoot.wifiOn
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, wifiRoot.expanded ? 0.25 : 0.15)
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
                    text: wifiRoot.wifiOn ? "󰤨" : "󰤭"
                    color: wifiRoot.wifiOn ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (wifiRoot.wifiOn) {
                            wifiRoot.runCommand(["nmcli", "radio", "wifi", "off"])
                            wifiRoot.wifiOn = false; wifiRoot.expanded = false
                        } else {
                            wifiRoot.runCommand(["nmcli", "radio", "wifi", "on"])
                            wifiRoot.wifiOn = true
                        }
                    }
                }
            }

            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (wifiRoot.wifiOn) { wifiRoot.expanded = !wifiRoot.expanded; if (wifiRoot.expanded) wifiRoot.scan() }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8
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
                            visible: wifiRoot.wifiOn && wifiRoot.ssid !== ""
                            text: wifiRoot.ssid
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: wifiRoot.wifiOn
                        text: wifiRoot.expanded ? "󰅃" : "󰅀"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }

    ColumnLayout {
        visible: wifiRoot.expanded && wifiRoot.wifiOn
        Layout.fillWidth: true
        spacing: 4

        Text {
            visible: wifiRoot.scanning
            Layout.alignment: Qt.AlignHCenter
            text: "Scanning..."
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }

        Repeater {
            model: wifiRoot.networks
            delegate: Rectangle {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8
                
                // Pure Local UI State overrides
                property bool isProcessing: itemProc.running
                property bool isConnecting: false
                property bool isDisconnecting: false

                property bool showActive: {
                    if (isDisconnecting) return false;
                    if (isConnecting) return true;
                    // Instantly uncheck visually if the user is connecting to a different network
                    if (wifiRoot.targetSsid !== "" && wifiRoot.targetSsid !== modelData.ssid) return false;
                    return modelData.active;
                }

                color: showActive
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                    : networkMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

                Process {
                    id: itemProc
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const out = text.trim();
                            if (out.toLowerCase().includes("error")) wifiRoot.notify("Wi-Fi Warning", out);
                        }
                    }
                    stderr: StdioCollector {
                        onStreamFinished: {
                            if (text.trim().length > 0) wifiRoot.notify("Wi-Fi Error", text.trim());
                        }
                    }
                    onRunningChanged: {
                        if (!running) {
                            // Clear local overrides and trigger a real state fetch
                            delegateRoot.isConnecting = false;
                            delegateRoot.isDisconnecting = false;
                            wifiRoot.targetSsid = "";
                            wifiPoll.running = true;
                        }
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: wifiRoot.signalIcon(modelData.signal)
                        color: delegateRoot.showActive ? Colors.primary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: modelData.ssid
                        color: delegateRoot.showActive ? Colors.primary : Colors.surfaceFg
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.security && !delegateRoot.showActive && !delegateRoot.isProcessing
                        text: "󰌾"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        visible: delegateRoot.showActive || delegateRoot.isProcessing
                        text: delegateRoot.isProcessing ? "󰔟" : "󰄬"
                        color: delegateRoot.isProcessing ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6) : Colors.primary
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                MouseArea {
                    id: networkMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: delegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (delegateRoot.isProcessing) return;
                        
                        let disconnecting = modelData.active;
                        wifiRoot.targetSsid = modelData.ssid; // Signals other delegates to visually drop active state

                        if (disconnecting) {
                            delegateRoot.isDisconnecting = true;
                            wifiRoot.ssid = "";
                        } else {
                            delegateRoot.isConnecting = true;
                            wifiRoot.ssid = modelData.ssid;
                        }
                        
                        itemProc.command = disconnecting
                            ? ["sh", "-c", "dev=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -n1); if [ -n \"$dev\" ]; then nmcli dev disconnect \"$dev\"; fi"]
                            : ["nmcli", "dev", "wifi", "connect", modelData.ssid];
                            
                        itemProc.running = true;
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
                onClicked: {
                    wifiRoot.runCommand(["nmcli", "dev", "wifi", "rescan"])
                    wifiRoot.scan()
                }
            }
        }
    }
}
