import QtQuick
import QtQuick.Layouts
import "."

// UI only. All state, processes and notifications live in BluetoothService
// (a singleton), because this component is destroyed every time the control
// panel closes.
ColumnLayout {
    id: btRoot
    spacing: Theme.spacingSM

    property bool expanded: false

    readonly property bool btOn: BluetoothService.powered
    readonly property bool powerBusy: BluetoothService.busy && BluetoothService.actionKind === "power"

    onExpandedChanged: if (expanded) BluetoothService.refresh()
    onBtOnChanged: if (!btOn) expanded = false

    // `kind` is BlueZ's Icon property (audio-headset, input-mouse, ...),
    // more reliable than guessing from the device name.
    function deviceIcon(name, kind) {
        switch (kind) {
        case "audio-headset":
        case "audio-headphones": return "󰋋"
        case "audio-card":       return "󰓃"
        case "input-mouse":      return "󰍽"
        case "input-keyboard":   return "󰌌"
        case "phone":            return "󰏲"
        }
        const n = (name || "").toLowerCase()
        if (n.includes("headphone") || n.includes("earphone") || n.includes("buds")) return "󰋋"
        if (n.includes("mouse")) return "󰍽"
        if (n.includes("keyboard")) return "󰌌"
        if (n.includes("phone")) return "󰏲"
        if (n.includes("speaker")) return "󰓃"
        return "󰂯"
    }

    // ── Header row ─────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.toggleHeight
        radius: Theme.toggleRadius
        color: btRoot.btOn
            ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, btRoot.expanded ? 0.25 : 0.15)
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
                    text: btRoot.powerBusy ? "󰔟" : "󰂯"
                    color: btRoot.btOn ? Colors.secondary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                    font.pixelSize: Theme.toggleIconSize
                    font.family: Theme.fontMono
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: BluetoothService.busy ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (BluetoothService.busy) return
                        if (btRoot.btOn) btRoot.expanded = false
                        BluetoothService.setPower(!btRoot.btOn)
                    }
                }
            }

            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (btRoot.btOn) btRoot.expanded = !btRoot.expanded
                }

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
                            font.family: Theme.fontMono
                        }
                        Text {
                            visible: text !== ""
                            text: !BluetoothService.hasAdapter ? "No adapter"
                                : (btRoot.btOn ? BluetoothService.connectedName : "")
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        visible: btRoot.btOn
                        text: btRoot.expanded ? "󰅃" : "󰅀"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 14
                        font.family: Theme.fontMono
                    }
                }
            }
        }
    }

    // ── Expanded device list ───────────────────────────────────────────
    ColumnLayout {
        visible: btRoot.expanded && btRoot.btOn
        Layout.fillWidth: true
        spacing: 4

        Text {
            visible: BluetoothService.devices.length === 0
                     && BluetoothService.discovered.length === 0
                     && !BluetoothService.scanning
            Layout.alignment: Qt.AlignHCenter
            text: "No paired devices"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: Theme.fontMono
        }

        Text {
            visible: BluetoothService.scanning
            Layout.alignment: Qt.AlignHCenter
            text: "Scanning..."
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: Theme.fontMono
        }

        // Paired devices
        Repeater {
            model: BluetoothService.devices
            delegate: Rectangle {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8

                property bool isProcessing: BluetoothService.busy && BluetoothService.targetMac === modelData.mac
                // Derived, not latched, so a failed disconnect can't leave the row stuck.
                readonly property bool isDisconnecting: isProcessing && modelData.connected
                readonly property bool showConnected: modelData.connected && !isDisconnecting

                color: showConnected
                    ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.2)
                    : deviceMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: btRoot.deviceIcon(modelData.name, modelData.icon)
                        color: delegateRoot.showConnected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: modelData.name
                        color: delegateRoot.showConnected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 12
                        font.family: Theme.fontMono
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: delegateRoot.showConnected || delegateRoot.isProcessing
                        text: delegateRoot.isProcessing ? "󰔟" : "󰄬"
                        color: delegateRoot.isProcessing ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6) : Colors.secondary
                        font.pixelSize: 12
                        font.family: Theme.fontMono
                    }
                }

                MouseArea {
                    id: deviceMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: delegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (BluetoothService.busy) return
                        BluetoothService.toggleDevice(modelData.mac, modelData.connected)
                    }
                }
            }
        }

        // Discovered (unpaired) devices
        Repeater {
            model: BluetoothService.discovered
            delegate: Rectangle {
                id: pairDelegateRoot
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8

                property bool isProcessing: BluetoothService.busy && BluetoothService.targetMac === modelData.mac

                color: pairMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.3)

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: btRoot.deviceIcon(modelData.name, modelData.icon)
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                        font.pixelSize: 14
                        font.family: Theme.fontMono
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: modelData.name
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.75)
                            font.pixelSize: 12
                            font.family: Theme.fontMono
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: !pairDelegateRoot.isProcessing
                            text: "Tap to pair"
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                        }
                    }
                    Text {
                        visible: pairDelegateRoot.isProcessing
                        text: "󰔟"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                        font.pixelSize: 12
                        font.family: Theme.fontMono
                    }
                }

                MouseArea {
                    id: pairMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pairDelegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (BluetoothService.busy) return
                        BluetoothService.pairDevice(modelData.mac)
                    }
                }
            }
        }

        // Scan button
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 8
            color: btRescanMa.containsMouse
                ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.15)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: BluetoothService.scanning ? "󰑐  Scanning..." : "󰑐  Scan for devices"
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                font.pixelSize: 11
                font.family: Theme.fontMono
            }
            MouseArea {
                id: btRescanMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.scan()
            }
        }
    }
}
