import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: wifiRoot
    spacing: Theme.spacingSM

    readonly property string fontFamily: Theme.fontMono

    readonly property bool wifiOn: NetworkService.wifiOn
    readonly property string ssid: NetworkService.ssid
    readonly property var networks: NetworkService.networks
    readonly property bool scanning: NetworkService.scanning

    property bool expanded: false
    readonly property bool actionInFlight: NetworkService.busy
    readonly property string targetSsid: NetworkService.targetSsid

    onExpandedChanged: {
        if (!expanded) NetworkService.cancelPasswordPrompt()
    }

    Connections {
        target: NetworkService
        function onConnectionSettled() {
            // Refresh the list so the active flags reflect the finished
            // connect/disconnect/rescan. Skipped while a password prompt is
            // open: scan() clears the model, which would destroy the field.
            if (wifiRoot.expanded && wifiRoot.wifiOn && NetworkService.awaitingPasswordFor === "")
                NetworkService.scan()
        }
    }

    function scan() {
        NetworkService.scan()
    }

    function rescan() {
        if (wifiRoot.actionInFlight || NetworkService.awaitingPasswordFor !== "") return
        // Only lock the UI if the command actually started; a dropped
        // command never fires connectionSettled and would lock it forever.
        NetworkService.runCommand(["nmcli", "dev", "wifi", "list", "--rescan", "yes"])
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.toggleHeight
        radius: Theme.toggleRadius
        color: wifiRoot.wifiOn
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, wifiRoot.expanded ? 0.25 : 0.15)
            : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.6)
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 8

            Rectangle {
                width: Theme.toggleIconBox; height: Theme.toggleIconBox; radius: width / 2
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: wifiRoot.wifiOn ? "󰤨" : "󰤭"
                    color: wifiRoot.wifiOn ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                    font.pixelSize: Theme.toggleIconSize
                    font.family: wifiRoot.fontFamily
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (wifiRoot.actionInFlight) return
                        const wasOn = wifiRoot.wifiOn
                        if (!NetworkService.toggleWifiRadio()) return
                        if (wasOn) wifiRoot.expanded = false
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
                readonly property bool isConnecting: isProcessing && !modelData.active
                readonly property bool isDisconnecting: isProcessing && modelData.active
                readonly property bool needsPassword: NetworkService.awaitingPasswordFor === modelData.ssid

                readonly property bool showActive: modelData.active && !isDisconnecting

                color: showActive
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                    : networkMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

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

                                modelData.active
                                    ? NetworkService.disconnectActive()
                                    : NetworkService.connectToNetwork(modelData.ssid)
                            }
                        }
                    }

                    RowLayout {
                        visible: delegateRoot.needsPassword
                        Layout.fillWidth: true
                        spacing: 6

                        TextField {
                            id: pwField
                            onVisibleChanged: if (visible) Qt.callLater(() => { if (visible) forceActiveFocus() })
                            Component.onCompleted: if (visible) Qt.callLater(() => { if (visible) forceActiveFocus() })
                            Layout.fillWidth: true
                            placeholderText: "Password"
                            echoMode: TextInput.Password
                            font.pixelSize: 11
                            font.family: wifiRoot.fontFamily
                            onAccepted: connectBtn.doConnect()
                        }

                        Text {
                            text: "Cancel"
                            color: Colors.surfaceFg
                            font.pixelSize: 11
                            font.family: wifiRoot.fontFamily
                            TapHandler {
                                onTapped: { pwField.clear(); NetworkService.cancelPasswordPrompt() }
                            }
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
                                if (NetworkService.connectToNetwork(modelData.ssid, pwField.text)) {
                                    pwField.clear()
                                }
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
