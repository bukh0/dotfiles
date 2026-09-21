import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: wifiRoot
    spacing: 6

    readonly property string fontFamily: Theme.fontMono

    readonly property bool wifiOn: NetworkService.wifiOn
    readonly property string ssid: NetworkService.ssid
    readonly property var networks: NetworkService.networks
    readonly property bool scanning: NetworkService.scanning

    property bool expanded: false
    property bool rescanPending: false
    property bool actionInFlight: false
    property string targetSsid: ""

    onExpandedChanged: {
        if (!expanded) NetworkService.cancelPasswordPrompt()
    }

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

    function rescan() {
        if (wifiRoot.actionInFlight) return
        wifiRoot.actionInFlight = true
        wifiRoot.rescanPending = true
        NetworkService.runCommand(["nmcli", "dev", "wifi", "rescan"])
    }

    // ── Wi‑Fi header ───────────────────────────────────────────
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
                    font.family: wifiRoot.fontFamily
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
                onClicked: {
                    if (wifiRoot.wifiOn) {
                        wifiRoot.expanded = !wifiRoot.expanded
                        if (wifiRoot.expanded) wifiRoot.scan()
                    }
                }

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
                            font.family: wifiRoot.fontFamily
                        }
                        Text {
                            visible: wifiRoot.wifiOn && wifiRoot.ssid !== ""
                            text: wifiRoot.ssid
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                            font.pixelSize: 10
                            font.family: wifiRoot.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: wifiRoot.wifiOn
                        text: wifiRoot.expanded ? "󰅃" : "󰅀"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 14
                        font.family: wifiRoot.fontFamily
                    }
                }
            }
        }
    }

    // ── Network list ───────────────────────────────────────────
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
            font.family: wifiRoot.fontFamily
        }

        Repeater {
            model: wifiRoot.networks
            delegate: Rectangle {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: contentCol.implicitHeight + 16
                radius: 8

                property bool isProcessing: wifiRoot.actionInFlight && wifiRoot.targetSsid === modelData.ssid
                property bool isConnecting: false
                property bool isDisconnecting: false
                readonly property bool needsPassword: NetworkService.awaitingPasswordFor === modelData.ssid

                readonly property bool showActive: modelData.active && !isDisconnecting

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

                ColumnLayout {
                    id: contentCol
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                    spacing: 6

                    Item {
                        id: headerItem
                        Layout.fillWidth: true
                        implicitHeight: headerLayout.implicitHeight

                        RowLayout {
                            id: headerLayout
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: NetworkService.signalIcon(modelData.signal)
                                color: delegateRoot.showActive ? Colors.primary : Colors.surfaceFg
                                font.pixelSize: 14
                                font.family: wifiRoot.fontFamily
                            }
                            Text {
                                text: modelData.ssid
                                color: delegateRoot.showActive ? Colors.primary : Colors.surfaceFg
                                font.pixelSize: 12
                                font.family: wifiRoot.fontFamily
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: modelData.security && !delegateRoot.showActive && !delegateRoot.isProcessing
                                text: "󰌾"
                                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                                font.pixelSize: 11
                                font.family: wifiRoot.fontFamily
                            }
                            Text {
                                visible: delegateRoot.showActive || delegateRoot.isProcessing
                                text: delegateRoot.isProcessing ? "󰔟" : "󰄬"
                                color: delegateRoot.isProcessing ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6) : Colors.primary
                                font.pixelSize: 12
                                font.family: wifiRoot.fontFamily
                            }
                        }

                        MouseArea {
                            id: networkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: delegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (wifiRoot.actionInFlight) return

                                const disconnecting = modelData.active
                                wifiRoot.actionInFlight = true
                                wifiRoot.targetSsid = modelData.ssid

                                if (disconnecting) {
                                    delegateRoot.isDisconnecting = true
                                    NetworkService.disconnectActive()
                                } else {
                                    delegateRoot.isConnecting = true
                                    // Tries without a secret first; NetworkService flips
                                    // awaitingPasswordFor if one turns out to be required,
                                    // which reveals the password row below.
                                    NetworkService.connectToNetwork(modelData.ssid)
                                }
                            }
                        }
                    }

                    // Password entry — shown when NetworkService reports this SSID
                    // rejected a connection attempt for lacking a secret. Previously
                    // there was no UI path for this at all: a new secured network
                    // would just silently fail to connect.
                    RowLayout {
                        visible: delegateRoot.needsPassword
                        Layout.fillWidth: true
                        spacing: 6

                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            placeholderText: "Password"
                            echoMode: TextInput.Password
                            font.pixelSize: 11
                            font.family: wifiRoot.fontFamily
                            onAccepted: connectBtn.doConnect()
                        }

                        Text {
                            id: connectBtn
                            text: "Connect"
                            color: Colors.primary
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: wifiRoot.fontFamily

                            function doConnect() {
                                if (pwField.text.length === 0) return
                                wifiRoot.actionInFlight = true
                                wifiRoot.targetSsid = modelData.ssid
                                delegateRoot.isConnecting = true
                                NetworkService.connectToNetwork(modelData.ssid, pwField.text)
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: connectBtn.doConnect()
                            }
                        }
                    }
                }
            }
        }

        // Rescan button
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
                font.family: wifiRoot.fontFamily
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
