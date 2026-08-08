import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: wifiRoot
    spacing: 6

    // Sourced from the shared singleton instead of local polling
    readonly property bool wifiOn: NetworkService.wifiOn
    readonly property string ssid: NetworkService.ssid
    readonly property var networks: NetworkService.networks
    readonly property bool scanning: NetworkService.scanning

    property bool expanded: false
    property bool rescanPending: false
    property bool actionInFlight: false

    // Helps delegates know to uncheck themselves when a new network is clicked
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

    Connections {
        target: NetworkService
        function onConnectionSettled() {
            wifiRoot.actionInFlight = false
            if (wifiRoot.rescanPending) {
                wifiRoot.rescanPending = false
                NetworkService.scan()
            }
        }
        function onCommandError(message) {
            wifiRoot.notify("Wi-Fi Error", message)
        }
    }

    function scan() {
        NetworkService.scan()
    }

    // Distinct from scan(): forces the radio to rediscover APs first, then
    // lists once that finishes (see the Connections handler above).
    function rescan() {
        if (wifiRoot.actionInFlight) return
        wifiRoot.actionInFlight = true
        wifiRoot.rescanPending = true
        NetworkService.runCommand(["nmcli", "dev", "wifi", "rescan"])
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
                        if (wifiRoot.actionInFlight) return
                        wifiRoot.actionInFlight = true
                        if (wifiRoot.wifiOn) wifiRoot.expanded = false
                        NetworkService.toggleWifiRadio()
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

                property bool isProcessing: wifiRoot.actionInFlight && wifiRoot.targetSsid === modelData.ssid
                property bool isConnecting: false
                property bool isDisconnecting: false

                property bool showActive: {
                    if (isDisconnecting) return false;
                    if (isConnecting) return true;
                    if (wifiRoot.targetSsid !== "" && wifiRoot.targetSsid !== modelData.ssid) return false;
                    return modelData.active;
                }

                color: showActive
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                    : networkMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

                Connections {
                    target: NetworkService
                    function onConnectionSettled() {
                        if (wifiRoot.targetSsid !== modelData.ssid) return
                        delegateRoot.isConnecting = false
                        delegateRoot.isDisconnecting = false
                        wifiRoot.targetSsid = ""
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
                        if (wifiRoot.actionInFlight) return;

                        let disconnecting = modelData.active;
                        wifiRoot.actionInFlight = true;
                        wifiRoot.targetSsid = modelData.ssid;

                        if (disconnecting) {
                            delegateRoot.isDisconnecting = true;
                            NetworkService.disconnectActive();
                        } else {
                            delegateRoot.isConnecting = true;
                            NetworkService.connectToNetwork(modelData.ssid);
                        }
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
                onClicked: wifiRoot.rescan()
            }
        }
    }
}
