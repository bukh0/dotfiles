pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as Native

// ── BluetoothService ──────────────────────────────────────────────────────
// Owns ALL Bluetooth state and processes. It is a singleton (like
// NetworkService) so it keeps running while the control panel is closed:
// connect/disconnect notifications keep working through native D-Bus updates.
// The legacy monitor is retained only for diagnostics.
//
// NOTE: QML singletons are created lazily. shell.qml must touch this once at
// startup (BluetoothService.refresh()) or nothing runs until the panel is
// first opened.
Item {
    id: root
    property bool nativeStatusEnabled: true
    property bool _nativeReady: false
    readonly property var nativeSnapshot: {
        const objects = {}
        for (const adapter of Native.Bluetooth.adapters.values)
            objects[adapter.dbusPath] = {"org.bluez.Adapter1": {Powered: {data: adapter.enabled}}}
        for (const device of Native.Bluetooth.devices.values) {
            objects[device.dbusPath] = {"org.bluez.Device1": {
                Address: {data: device.address}, Alias: {data: device.name},
                Name: {data: device.deviceName}, Icon: {data: device.icon},
                Paired: {data: device.paired}, Connected: {data: device.connected}
            }}
        }
        return JSON.stringify({data: [objects]})
    }
    onNativeSnapshotChanged: if (_nativeReady && nativeStatusEnabled) nativeSync.restart()
    Timer { id: nativeSync; interval: 0; onTriggered: root.refresh() }


    // ── Public state (read by BluetoothToggle) ─────────────────────────
    property bool hasAdapter: false
    property bool powered: false
    property string connectedName: ""
    property var devices: []          // paired:   { mac, name, connected, icon }
    property var discovered: []       // unpaired: { mac, name, icon }
    property bool scanning: false
    property bool busy: false         // a power/connect/pair command is running
    property string actionKind: ""    // "power" | "connect" | "pair" while busy
    property string targetMac: ""

    readonly property int maxDiscovered: 8
    readonly property int scanSeconds: 8

    // ── Internal state ─────────────────────────────────────────────────
    property var _prevConnected: null
    property var _prevNames: ({})
    property bool _pollQueued: false
    property bool _pollInFlight: false
    property bool _pollErrorLogged: false
    property int _monitorDelay: 250

    // ── Helpers ────────────────────────────────────────────────────────
    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Bluetooth", "--", title, body])
    }

    function _assign(prop, value) {
        if (JSON.stringify(root[prop]) !== JSON.stringify(value)) root[prop] = value
    }

    function _stripAnsi(s) {
        return (s || "").replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\r/g, "")
    }

    // ── State polling (BlueZ ObjectManager over busctl) ────────────────
    function refresh() {
        if (nativeStatusEnabled) { _nativeReady = true; root._applyManagedObjects(nativeSnapshot); return }
        // Never drop a request: if a poll is in flight its data may already
        // be stale, so remember to run one more when it finishes.
        if (root._pollInFlight) {
            root._pollQueued = true
            return
        }
        root._pollInFlight = true
        btPoll.started = false
        btPoll.exited = false
        btPoll.streamDone = false
        btPoll.output = ""
        btPoll.ok = false
        pollLaunchCheck.restart()
        btPoll.running = true
    }

    function _finishPoll() {
        if (!root._pollInFlight || !btPoll.exited || !btPoll.streamDone) return
        pollLaunchCheck.stop()
        if (btPoll.started && btPoll.ok) root._applyManagedObjects(btPoll.output)
        else root._markUnavailable()
        root._pollInFlight = false
        if (root._pollQueued) {
            root._pollQueued = false
            root.refresh()
        }
    }

    Timer {
        id: pollLaunchCheck
        interval: 500
        onTriggered: {
            if (root._pollInFlight && !btPoll.started && !btPoll.running) {
                btPoll.exited = true
                btPoll.streamDone = true
                root._finishPoll()
            }
        }
    }

    function _markUnavailable() {
        root.hasAdapter = false
        root.powered = false
        root.connectedName = ""
        root._prevConnected = null
        root._prevNames = {}
        root._assign("devices", [])
        root._assign("discovered", [])
    }

    function _applyManagedObjects(rawText) {
        let parsed
        try {
            parsed = JSON.parse(rawText)
        } catch (e) {
            // Empty/invalid output = bluetoothd not running or busctl failed.
            root._markUnavailable()
            return
        }
        root._pollErrorLogged = false

        const macLike = /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i
        const objs = (parsed.data && parsed.data[0]) || {}

        let adapterFound = false
        let adapterPowered = false
        const known = {}   // mac -> record (merged if listed under several adapters)

        for (const path in objs) {
            const ifaces = objs[path]

            const adapter = ifaces["org.bluez.Adapter1"]
            if (adapter) {
                adapterFound = true
                // Any powered adapter counts (was: last one listed won).
                if (adapter.Powered && adapter.Powered.data) adapterPowered = true
            }

            const dev = ifaces["org.bluez.Device1"]
            if (!dev || !dev.Address || !dev.Address.data) continue

            const mac = dev.Address.data
            // Alias first: it's what the user sees/renames and what
            // bluetoothctl prints. It defaults to Name anyway.
            const alias = (dev.Alias && dev.Alias.data) || (dev.Name && dev.Name.data) || ""
            const rec = {
                mac: mac,
                name: alias || mac,
                // Nameless devices get an alias like "AA-BB-CC-DD-EE-FF".
                hasName: alias !== "" && !macLike.test(alias),
                icon: (dev.Icon && dev.Icon.data) || "",
                paired: !!(dev.Paired && dev.Paired.data),
                connected: !!(dev.Connected && dev.Connected.data),
                rssi: (dev.RSSI && typeof dev.RSSI.data === "number") ? dev.RSSI.data : -999
            }

            const prev = known[mac]
            if (prev) {
                if (!prev.hasName && rec.hasName) {
                    prev.name = rec.name
                    prev.hasName = true
                }
                if (!prev.icon && rec.icon) prev.icon = rec.icon
                prev.paired = prev.paired || rec.paired
                prev.connected = prev.connected || rec.connected
                prev.rssi = Math.max(prev.rssi, rec.rssi)
            } else {
                known[mac] = rec
            }
        }

        root.hasAdapter = adapterFound
        root.powered = adapterPowered

        if (!adapterPowered) {
            // Powering off disconnects everything; don't fire a burst of
            // "Disconnected" notifications for it.
            root.connectedName = ""
            root._prevConnected = null
            root._prevNames = {}
            root._assign("devices", [])
            root._assign("discovered", [])
            return
        }

        const all = Object.values(known)

        // Connected devices need disconnect controls even without a bond.
        const paired = all
            .filter(d => d.paired || d.connected)
            .map(d => ({ mac: d.mac, name: d.name, connected: d.connected, icon: d.icon }))
            .sort((a, b) => (Number(b.connected) - Number(a.connected)) || a.name.localeCompare(b.name))

        // Strongest signal first (devices not seen recently have no RSSI and
        // sink to the bottom), capped so the panel can't grow off-screen.
        const discovered = all
            .filter(d => !d.paired && !d.connected && d.hasName)
            .sort((a, b) => (b.rssi - a.rssi) || a.name.localeCompare(b.name))
            .slice(0, root.maxDiscovered)
            .map(d => ({ mac: d.mac, name: d.name, icon: d.icon }))

        const connected = all.filter(d => d.connected)
        const connectedMacs = connected.map(d => d.mac)
        root.connectedName = connected.map(d => d.name).join(", ")

        // Connect/disconnect notifications. First poll only seeds state.
        if (root._prevConnected !== null) {
            for (const d of connected) {
                if (!root._prevConnected.includes(d.mac))
                    root.notify("Bluetooth Connected", d.name)
            }
            for (const mac of root._prevConnected) {
                if (!connectedMacs.includes(mac))
                    root.notify("Bluetooth Disconnected", root._prevNames[mac] || "Device")
            }
        }
        root._prevConnected = connectedMacs

        // Names for every known device (was: paired only, so a connected but
        // unpaired device came out as just "Device").
        const names = {}
        for (const d of all) names[d.mac] = d.name
        root._prevNames = names

        root._assign("devices", paired)
        root._assign("discovered", discovered)
    }

    Process {
        id: btPoll
        property bool started: false
        property bool exited: false
        property bool streamDone: false
        property bool ok: false
        property string output: ""
        onStarted: { started = true; pollLaunchCheck.stop() }
        onExited: (code, status) => {
            exited = true
            ok = code === 0 && status === 0
            pollSettled.restart()
        }
        command: ["busctl", "--system", "-j", "call", "org.bluez", "/",
                  "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: {
                btPoll.output = btPoll.started ? text : ""
                btPoll.streamDone = true
                pollSettled.restart()
            }
        }
        // Log only. Notifying here spammed "Bluetooth Warning" on every
        // poll whenever bluetoothd wasn't running.
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = btPoll.started ? text.trim() : ""
                if (msg !== "" && !root._pollErrorLogged) {
                    root._pollErrorLogged = true
                    console.warn("bluetooth: busctl:", msg)
                }
            }
        }
    }

    Timer {
        id: pollSettled
        interval: 0
        onTriggered: root._finishPoll()
    }

    Timer {
        interval: 20000
        running: !root.nativeStatusEnabled
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: monitorDebounce
        interval: 300
        onTriggered: root.refresh()
    }

    // ── D-Bus monitor: re-poll on relevant BlueZ signals ───────────────
    Timer {
        id: btStableTimer
        interval: 5000
        onTriggered: root._monitorDelay = 250
    }

    Timer {
        id: btMonitorRestart
        interval: 250
        onTriggered: if (!root.nativeStatusEnabled) btMonitor.running = true
    }

    Process {
        id: btMonitor
        command: ["dbus-monitor", "--system",
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'",
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.ObjectManager'"
        ]
        running: !root.nativeStatusEnabled
        stdout: SplitParser {
            onRead: line => {
                // InterfacesAdded/Removed = device discovered / forgotten,
                // which PropertiesChanged alone never reports.
                if (line.includes("member=InterfacesAdded")
                    || line.includes("member=InterfacesRemoved")
                    || line.includes("Connected")
                    || line.includes("Powered")
                    || line.includes("Paired")
                    || line.includes("Name")
                    || line.includes("Alias"))
                    monitorDebounce.restart()
            }
        }
        onRunningChanged: {
            if (running) {
                btStableTimer.restart()
                root.refresh()   // catch anything missed while it was down
                return
            }
            btStableTimer.stop()
            if (root.nativeStatusEnabled) return
            btMonitorRestart.interval = root._monitorDelay
            btMonitorRestart.restart()
            root._monitorDelay = Math.min(root._monitorDelay * 2, 30000)
        }
    }

    // ── Actions (power / connect / disconnect / pair) ──────────────────
    // Every command runs through a small sh wrapper that prints
    //   <exit code>\n<combined stdout+stderr>
    // on stdout. Result and exit status therefore arrive together in ONE
    // stream; the old code read collector .text inside onExited, which can
    // run before the collectors have finished and silently lost errors.
    Process {
        id: actionProc
        property bool started: false
        onStarted: { started = true; actionLaunchCheck.stop() }
        property bool _exited: false
        property bool _streamDone: false
        stdout: StdioCollector {
            id: actionOut
            onStreamFinished: {
                actionProc._streamDone = true
                if (actionProc._exited) root._finishAction()
            }
        }
        onExited: {
            actionProc._exited = true
            if (actionProc._streamDone) root._finishAction()
        }
    }

    // Safety net: if actionProc never starts, clear busy so the UI isn't
    // locked forever. Mirrors NetworkService.commandLaunchCheck.
    Timer {
        id: actionLaunchCheck
        interval: 500
        onTriggered: if (!actionProc.started && !actionProc.running && root.busy) root._finishAction()
    }

    function _startAction(kind, mac, script, args) {
        if (root.busy || actionProc.running) return false
        actionProc.started = false
        actionProc._exited = false
        actionProc._streamDone = false
        root.busy = true
        root.actionKind = kind
        root.targetMac = mac || ""
        const wrapper = "out=$({ " + script + "; } 2>&1); rc=$?; printf '%s\\n%s' \"$rc\" \"$out\""
        actionProc.command = ["sh", "-c", wrapper, "sh"].concat(args || [])
        actionLaunchCheck.restart()
        actionProc.running = true
        return true
    }

    function _finishAction() {
        if (!root.busy) return
        actionLaunchCheck.stop()

        // A failed spawn can leave StdioCollector.text from the previous run.
        const raw = actionProc.started ? (actionOut.text || "") : ""
        const nl = raw.indexOf("\n")
        const rc = parseInt(nl >= 0 ? raw.slice(0, nl) : raw)
        const out = root._stripAnsi(nl >= 0 ? raw.slice(nl + 1) : "").trim()

        const kind = root.actionKind
        root.busy = false
        root.actionKind = ""
        root.targetMac = ""

        if (isNaN(rc)) {
            root.notify("Bluetooth Warning", "Command failed to run")
        } else {
            root._reportResult(rc, out, kind)
        }
        root.refresh()
    }

    function _reportResult(rc, out, kind) {
        const lines = out.split("\n").map(l => l.trim()).filter(l => l !== "")

        // The pairing helper reports through its exit code. GTK/Blueman print
        // unrelated module-load errors even when pairing succeeds.
        if (kind === "pair") {
            if (rc === 0) return
            const own = lines.filter(l => l.startsWith("Bluetooth pairing failed:"))
            const msg = own.length > 0 ? own[own.length - 1]
                : (lines.length > 0 ? lines[lines.length - 1] : "Pairing failed (exit " + rc + ")")
            root.notify("Bluetooth Warning", msg)
            return
        }

        if (rc === 124) {
            root.notify("Bluetooth Warning", "Timed out. Is the device on and in range?")
            return
        }
        const bad = lines.filter(l => /^(?:Failed to\b|org\.bluez\.Error\b)/i.test(l))
        // Pairing often auto-connects, so the follow-up connect reports this.
        if (bad.length > 0 && bad.every(l => /org\.bluez\.Error\.AlreadyConnected\b/i.test(l))) return

        if (rc === 0 && bad.length === 0) return

        // Older bluetoothctl exits 0 even on failure, hence the text check.
        // Show the one relevant line, not the whole transcript.
        const msg = bad.length > 0 ? bad[bad.length - 1]
            : (lines.length > 0 ? lines[lines.length - 1] : "Command failed (exit " + rc + ")")
        root.notify("Bluetooth Warning", msg)
    }

    function _validMac(mac) {
        return /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(mac || "")
    }

    function setPower(on) {
        // rfkill first: a soft-blocked adapter otherwise fails with
        // "org.bluez.Error.Blocked".
        const accepted = root._startAction("power", "",
            on ? "rfkill unblock bluetooth 2>/dev/null; timeout 15 bluetoothctl power on"
               : "timeout 15 bluetoothctl power off", [])
        if (accepted && !on) stopScan()
        return accepted
    }

    function toggleDevice(mac, connected) {
        if (!root._validMac(mac)) return false
        // timeout: a hung bluetoothctl used to lock the whole UI forever.
        return root._startAction("connect", mac,
            connected ? "timeout 15 bluetoothctl disconnect \"$1\""
                      : "timeout 30 bluetoothctl connect \"$1\"", [mac])
    }

    function pairDevice(mac) {
        if (!root._validMac(mac)) return false
        return root._startAction("pair", mac,
            "python3 \"$1\" \"$2\"", [Quickshell.shellPath("../../native/bluetooth_pair.py"), mac])
    }

    // ── Scanning ───────────────────────────────────────────────────────
    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", String(root.scanSeconds), "scan", "on"]
        onRunningChanged: {
            if (!running) {
                root.scanning = false
                root.refresh()
            }
        }
    }

    // Recover from failed launches and processes stuck beyond their own timeout.
    Timer {
        interval: (root.scanSeconds + 4) * 1000
        running: root.scanning
        onTriggered: root.stopScan()
    }

    function stopScan() {
        scanProc.running = false
        root.scanning = false
    }

    onPoweredChanged: if (!powered) stopScan()

    function scan() {
        if (!root.powered || root.actionKind === "power" || scanProc.running) return
        root.scanning = true
        scanProc.running = true
    }

    Component.onCompleted: root.refresh()
}
