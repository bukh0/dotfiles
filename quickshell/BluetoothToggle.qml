import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: root
    spacing: 6

    property bool btOn: false
    property bool expanded: false
    property var devices: []
    property bool scanning: false

    // ---- Shared Process ----
    property var cmdProc: Process {
        id: cmdProc
        running: false
    }

    function runCommand(cmd) {
        console.log("BT: Running command:", cmd.join(" "))
        let onFinished = function() {
            console.log("BT: Command finished:", cmd.join(" "))
            cmdProc.finished.disconnect(onFinished)
            cmdProc.failed.disconnect(onFailed)
        }
        let onFailed = function() {
            console.log("BT: Command FAILED:", cmd.join(" "))
            cmdProc.finished.disconnect(onFinished)
            cmdProc.failed.disconnect(onFailed)
        }
        cmdProc.finished.connect(onFinished)
        cmdProc.failed.connect(onFailed)
        cmdProc.command = cmd
        cmdProc.running = true
    }
    // ---- end ----

    Process {
        id: btPoll
        command: ["sh", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: btOn = text.trim() === "yes"
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: btPoll.running = true
    }

    Process {
        id: devicePoll
        command: ["sh", "-c", "bluetoothctl devices | while read _ mac name; do connected=$(bluetoothctl info $mac | grep 'Connected:' | awk '{print $2}'); paired=$(bluetoothctl info $mac | grep 'Paired:' | awk '{print $2}'); echo \"$mac|$name|$connected|$paired\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                scanning = false
                const lines = text.trim().split("\n").filter(l => l.includes("|"))
                devices = lines.map(line => {
                    const parts = line.split("|")
                    return {
                        mac: parts[0]?.trim() || "",
                        name: parts[1]?.trim() || "Unknown",
                        connected: parts[2]?.trim() === "yes",
                        paired: parts[3]?.trim() === "yes"
                    }
                }).filter(d => d.mac !== "")
            }
        }
    }

    function scan() {
        scanning = true
        devices = []
        devicePoll.running = true
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

    // Header row
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 10
        color: btOn
            ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, expanded ? 0.25 : 0.15)
            : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.6)
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 8

            Text {
                text: "󰂯"
                color: btOn ? Colors.secondary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
            }

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
                    visible: btOn && devices.filter(d => d.connected).length > 0
                    text: devices.filter(d => d.connected).map(d => d.name).join(", ")
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: btOn
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
                if (!btOn) {
                    root.runCommand(["bluetoothctl", "power", "on"])
                    Qt.callLater(() => btPoll.running = true)
                } else {
                    expanded = !expanded
                    if (expanded) scan()
                }
            }
        }
    }

    // Expanded device list
    ColumnLayout {
        visible: expanded && btOn
        Layout.fillWidth: true
        spacing: 4

        Text {
            visible: scanning
            Layout.alignment: Qt.AlignHCenter
            text: "Loading devices..."
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }

        Text {
            visible: !scanning && devices.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: "No paired devices"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
        }

        Repeater {
            model: devices

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8
                color: modelData.connected
                    ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.2)
                    : deviceMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.5)

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: deviceIcon(modelData.name)
                        color: modelData.connected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                        text: modelData.name
                        color: modelData.connected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: modelData.connected
                        text: "󰄬"
                        color: Colors.secondary
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                MouseArea {
                    id: deviceMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let cmd = modelData.connected
                            ? ["bluetoothctl", "disconnect", modelData.mac]
                            : ["bluetoothctl", "connect", modelData.mac]
                        root.runCommand(cmd)
                        Qt.callLater(() => scan())
                    }
                }
            }
        }
    }
}
