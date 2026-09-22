import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: btRoot
    spacing: 6

    // ── State ──────────────────────────────────────────────────
    property bool btOn: false
    property string connectedName: ""
    property bool expanded: false
    property var devices: []
    property var discoveredDevices: []

    property bool scanning: false
    property string targetMac: ""
    property bool actionInFlight: false

    // Used for detecting connection changes
    property var previousConnected: null
    property var previousDeviceNames: ({})

    // ── Shared notification helper ─────────────────────────────
    Process {
        id: notifyProc
        running: false
    }

    function notify(title, body) {
        if (notifyProc.running) return
        notifyProc.command = ["notify-send", "-a", "Bluetooth", "-u", "critical", title, body]
        notifyProc.running = true
    }

    // ── Font ───────────────────────────────────────────────────
    readonly property string fontFamily: Theme.fontMono

    // ── Generic command runner (for power toggle etc.) ─────────
    Process {
        id: actionProc
        running: false
        stderr: StdioCollector { onStreamFinished: btRoot._checkError(text) }
        onRunningChanged: {
            if (!running) btPoll.running = true   // refresh full state
        }
    }

    function runCommand(cmdArray) {
        if (actionProc.running) return
        actionProc.command = cmdArray
        actionProc.running = true
    }

    // ── Main polling process — reads BlueZ's D-Bus state directly.
    // NOTE: known open issue — some devices (e.g. non-standard-profile
    // audio devices with a virtualized MAC like 00:00:00:00:03:80) can be
    // actively connected at the audio layer while org.bluez.Device1's
    // Connected property still reports false. Still investigating the
    // root cause; UI will under-report "connected" for those devices
    // until resolved.
    Process {
        id: btPoll
        command: ["busctl", "--system", "-j", "call", "org.bluez", "/",
                  "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stderr: StdioCollector { onStreamFinished: btRoot._checkError(text) }
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    console.warn("bluetooth: failed to parse busctl output:", e)
                    return
                }
                const objs = (parsed.data && parsed.data[0]) || {}

                let adapterPowered = false
                const paired = []
                const connectedMacs = []
                const connectedNames = []

                for (const path in objs) {
                    const ifaces = objs[path]

                    const adapter = ifaces["org.bluez.Adapter1"]
                    if (adapter && adapter.Powered) adapterPowered = !!adapter.Powered.data

                    const dev = ifaces["org.bluez.Device1"]
                    if (!dev || !dev.Paired || !dev.Paired.data) continue

                    const mac = dev.Address ? dev.Address.data : ""
                    if (!mac) continue
                    const name = (dev.Name && dev.Name.data) || (dev.Alias && dev.Alias.data) || mac
                    const connected = !!(dev.Connected && dev.Connected.data)

                    paired.push({ mac, name, connected })
                    if (connected) {
                        connectedMacs.push(mac)
                        connectedNames.push(name)
                    }
                }

                btRoot.btOn = adapterPowered

                if (!adapterPowered) {
                    btRoot.previousConnected = []
                    btRoot.devices = []
                    btRoot.connectedName = ""
                    btRoot.discoveredDevices = []
                    return
                }

                btRoot.connectedName = connectedNames.join(", ")
                btRoot.devices = paired

                // Clean up discovered list (remove newly paired devices)
                if (btRoot.discoveredDevices.length > 0) {
                    const pairedMacs = paired.map(d => d.mac)
                    btRoot.discoveredDevices = btRoot.discoveredDevices.filter(d => !pairedMacs.includes(d.mac))
                }

                // Connection change notifications
                if (btRoot.previousConnected !== null) {
                    const prevMacs = btRoot.previousConnected
                    const added = connectedMacs.filter(m => !prevMacs.includes(m))
                    const removed = prevMacs.filter(m => !connectedMacs.includes(m))
                    added.forEach(m => {
                        const d = paired.find(x => x.mac === m)
                        if (d) btRoot.notify("Bluetooth Connected", d.name)
                    })
                    removed.forEach(m => {
                        const name = btRoot.previousDeviceNames[m] || "Device"
                        btRoot.notify("Bluetooth Disconnected", name)
                    })
                }
                btRoot.previousConnected = connectedMacs

                const nameMap = {}
                paired.forEach(d => { nameMap[d.mac] = d.name })
                btRoot.previousDeviceNames = nameMap
            }
        }
    }

    // ── Event-driven refresh ───────────────────────────────────
    // dbus-monitor watches BlueZ's PropertiesChanged signals directly
    // on the system bus. Unlike the old `bluetoothctl` interactive
    // session (whose stdout was block-buffered when piped, causing
    // events to silently stall), dbus-monitor is designed for pipe
    // consumption and flushes immediately — so connections made by
    // any process (blueman, bluetoothctl CLI, KDE Connect, etc.)
    // are picked up within the debounce window.
    Timer {
        id: monitorDebounce
        interval: 300
        onTriggered: btPoll.running = true
    }

    Process {
        id: btMonitor
        command: ["dbus-monitor", "--system",
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"
        ]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                if (!(line.includes("Connected") || line.includes("Powered") || line.includes("Paired"))) return
                if (btPoll.running || actionProc.running || btRoot.actionInFlight) return
                monitorDebounce.restart()
            }
        }
        onRunningChanged: {
            if (!running) btMonitorRestart.start()
        }
    }

    Timer {
        id: btMonitorRestart
        interval: 2000
        onTriggered: btMonitor.running = true
    }

    // ── Fallback poll ────────────────────────────────────────
    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: {
            if (!btPoll.running && !actionProc.running && !btRoot.actionInFlight)
                btPoll.running = true
        }
    }

    Component.onCompleted: btPoll.running = true

    // ── Discovery helpers ──────────────────────────────────────
    Process {
        id: listAllPoll
        command: ["sh", "-c",
            "env NO_COLOR=1 bluetoothctl devices Paired; echo '==='; env NO_COLOR=1 bluetoothctl devices"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const textOutput = text.replace(/\x1b\[[0-9;]*m/g, "").trim()
                const sections = textOutput.split("===")
                if (sections.length < 2) return

                const pairedLines = sections[0].trim().split("\n").filter(l => l.includes("Device "))
                const allLines = sections[1].trim().split("\n").filter(l => l.includes("Device "))

                const pairedMacs = pairedLines.map(l => l.split(" ")[1]).filter(m => m)
                const seen = {}
                const unpaired = []
                for (const l of allLines) {
                    const parts = l.split(" ")
                    const mac = parts[1]
                    const name = parts.slice(2).join(" ").trim()
                    if (!mac || seen[mac] || pairedMacs.includes(mac)) continue
                    if (!name) continue
                    seen[mac] = true
                    unpaired.push({ mac, name })
                }
                btRoot.discoveredDevices = unpaired
            }
        }
    }

    Process {
        id: btScanProc
        command: ["bluetoothctl", "--timeout", "6", "scan", "on"]
        onRunningChanged: {
            if (!running) {
                btRoot.scanning = false
                listAllPoll.running = true
            }
        }
    }

    function listAll() {
        if (!listAllPoll.running) listAllPoll.running = true
    }

    function rescan() {
        if (btScanProc.running) return
        scanning = true
        btScanProc.running = true
    }

    // ── Internal error checker ─────────────────────────
    function _checkError(rawText) {
        const t = rawText.trim()
        if (t.length === 0) return
        if (t.toLowerCase().includes("error") || t.toLowerCase().includes("failed")) {
            btRoot.notify("Bluetooth Warning", t)
        }
    }

    // ── Icon mapping ───────────────────────────────────────────
    function deviceIcon(name) {
        const n = name.toLowerCase()
        if (n.includes("headphone") || n.includes("earphone") || n.includes("buds")) return "󰋋"
        if (n.includes("mouse")) return "󰍽"
        if (n.includes("keyboard")) return "󰌌"
        if (n.includes("phone")) return "󰏲"
        if (n.includes("speaker")) return "󰓃"
        return "󰂯"
    }

    // ── Connection Actions ─────────────────────────────────────
    Process {
        id: rootConnectProc
        running: false
        stderr: StdioCollector { onStreamFinished: btRoot._checkError(text) }
        onRunningChanged: {
            if (!running) {
                btRoot.actionInFlight = false
                btRoot.targetMac = ""
                btPoll.running = true
            }
        }
    }

    Process {
        id: rootPairProc
        running: false
        stderr: StdioCollector { onStreamFinished: btRoot._checkError(text) }
        onRunningChanged: {
            if (!running) {
                btRoot.actionInFlight = false
                btRoot.targetMac = ""
                btPoll.running = true
                listAllPoll.running = true
            }
        }
    }

    // ── Header toggle ──────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        radius: Theme.radius
        color: btRoot.btOn
            ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, btRoot.expanded ? 0.2 : 0.12)
            : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.4)
        border.color: btRoot.btOn
            ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.4)
            : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8

            // Power button
            Rectangle {
                width: 26; height: 26; radius: Theme.radiusSM
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: actionProc.running ? "󰔟" : "󰂯"
                    color: btRoot.btOn ? Colors.secondary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                    font.pixelSize: 20
                    font.family: btRoot.fontFamily
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: actionProc.running ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (actionProc.running) return
                        if (btRoot.btOn) {
                            btRoot.expanded = false
                            btRoot.runCommand(["bluetoothctl", "power", "off"])
                        } else {
                            btRoot.runCommand(["bluetoothctl", "power", "on"])
                        }
                    }
                }
            }

            // Expand / collapse area
            MouseArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (btRoot.btOn) {
                        btRoot.expanded = !btRoot.expanded
                        if (btRoot.expanded) btRoot.listAll()
                    }
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
                            font.family: btRoot.fontFamily
                        }
                        Text {
                            visible: btRoot.btOn && btRoot.connectedName !== ""
                            text: btRoot.connectedName
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.55)
                            font.pixelSize: 10
                            font.family: btRoot.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: btRoot.btOn
                        text: btRoot.expanded ? "󰅃" : "󰅀"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 14
                        font.family: btRoot.fontFamily
                    }
                }
            }
        }
    }

    // ── Expanded device list ───────────────────────────────────
    ColumnLayout {
        visible: btRoot.expanded && btRoot.btOn
        Layout.fillWidth: true
        spacing: 4

        Text {
            visible: btRoot.devices.length === 0 && btRoot.discoveredDevices.length === 0 && !btRoot.scanning
            Layout.alignment: Qt.AlignHCenter
            text: "No paired devices"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: btRoot.fontFamily
        }

        Text {
            visible: btRoot.scanning
            Layout.alignment: Qt.AlignHCenter
            text: "Scanning..."
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 11
            font.family: btRoot.fontFamily
        }

        // Paired devices
        Repeater {
            model: btRoot.devices
            delegate: Rectangle {
                id: delegateRoot
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 4

                property bool isProcessing: btRoot.actionInFlight && btRoot.targetMac === modelData.mac
                property bool isDisconnecting: false

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
                        text: btRoot.deviceIcon(modelData.name)
                        color: delegateRoot.showConnected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 14
                        font.family: btRoot.fontFamily
                    }
                    Text {
                        text: modelData.name
                        color: delegateRoot.showConnected ? Colors.secondary : Colors.surfaceFg
                        font.pixelSize: 12
                        font.family: btRoot.fontFamily
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: delegateRoot.showConnected || delegateRoot.isProcessing
                        text: delegateRoot.isProcessing ? "󰔟" : "󰄬"
                        color: delegateRoot.isProcessing ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6) : Colors.secondary
                        font.pixelSize: 12
                        font.family: btRoot.fontFamily
                    }
                }

                MouseArea {
                    id: deviceMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: delegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (btRoot.actionInFlight) return

                        const disconnecting = modelData.connected
                        if (disconnecting) delegateRoot.isDisconnecting = true

                        btRoot.actionInFlight = true
                        btRoot.targetMac = modelData.mac

                        rootConnectProc.command = disconnecting
                            ? ["bluetoothctl", "disconnect", modelData.mac]
                            : ["bluetoothctl", "connect", modelData.mac]
                        rootConnectProc.running = true
                    }
                }
            }
        }

        // Discovered (unpaired) devices
        Repeater {
            model: btRoot.discoveredDevices
            delegate: Rectangle {
                id: pairDelegateRoot
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 4

                property bool isProcessing: btRoot.actionInFlight && btRoot.targetMac === modelData.mac

                color: pairMa.containsMouse
                    ? Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    : Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.3)

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: btRoot.deviceIcon(modelData.name)
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                        font.pixelSize: 14
                        font.family: btRoot.fontFamily
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: modelData.name
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.75)
                            font.pixelSize: 12
                            font.family: btRoot.fontFamily
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: !pairDelegateRoot.isProcessing
                            text: "Tap to pair"
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                            font.pixelSize: 10
                            font.family: btRoot.fontFamily
                        }
                    }
                    Text {
                        visible: pairDelegateRoot.isProcessing
                        text: "󰔟"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                        font.pixelSize: 12
                        font.family: btRoot.fontFamily
                    }
                }

                MouseArea {
                    id: pairMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pairDelegateRoot.isProcessing ? Qt.WaitCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (btRoot.actionInFlight) return
                        const mac = modelData.mac
                        btRoot.actionInFlight = true
                        btRoot.targetMac = mac
                        rootPairProc.command = ["sh", "-c",
                            "bluetoothctl pair '" + mac + "' && bluetoothctl trust '" + mac + "' && bluetoothctl connect '" + mac + "'"]
                        rootPairProc.running = true
                    }
                }
            }
        }

        // Scan button
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 4
            color: btRescanMa.containsMouse
                ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.15)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: btRoot.scanning ? "󰑐  Scanning..." : "󰑐  Scan for devices"
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                font.pixelSize: 11
                font.family: btRoot.fontFamily
            }
            MouseArea {
                id: btRescanMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btRoot.rescan()
            }
        }
    }
}
