pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ── BluetoothService ──────────────────────────────────────────────────────
// Owns ALL Bluetooth state and processes. It is a singleton (like
// NetworkService) so it keeps running while the control panel is closed:
// connect/disconnect notifications keep working and the D-Bus monitor is
// spawned once instead of on every panel open.
//
// NOTE: QML singletons are created lazily. shell.qml must touch this once at
// startup (BluetoothService.refresh()) or nothing runs until the panel is
// first opened.
Item {
    id: root

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
        // Never drop a request: if a poll is in flight its data may already
        // be stale, so remember to run one more when it finishes.
        if (btPoll.running) {
            root._pollQueued = true
            return
        }
        btPoll.running = true
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

        const paired = all
            .filter(d => d.paired)
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
        command: ["busctl", "--system", "-j", "call", "org.bluez", "/",
                  "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: root._applyManagedObjects(text)
        }
        // Log only. Notifying here spammed "Bluetooth Warning" on every
        // poll whenever bluetoothd wasn't running.
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg !== "" && !root._pollErrorLogged) {
                    root._pollErrorLogged = true
                    console.warn("bluetooth: busctl:", msg)
                }
            }
        }
        // Chain follow-up work off "process finished", not off "stdout
        // finished" (at which point running is usually still true).
        onRunningChanged: {
            if (!running && root._pollQueued) {
                root._pollQueued = false
                running = true
            }
        }
    }

    Timer {
        interval: 20000
        running: true
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
        onTriggered: btMonitor.running = true
    }

    Process {
        id: btMonitor
        command: ["dbus-monitor", "--system",
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'",
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.ObjectManager'"
        ]
        running: true
        stdout: SplitParser {
            onRead: line => {
                // InterfacesAdded/Removed = device discovered / forgotten,
                // which PropertiesChanged alone never reports.
                if (line.includes("member=InterfacesAdded")
                    || line.includes("member=InterfacesRemoved")
                    || line.includes("Connected")
                    || line.includes("Powered")
                    || line.includes("Paired"))
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
        stdout: StdioCollector { id: actionOut }
        onRunningChanged: {
            if (!running && root.busy) actionFinalize.restart()
        }
    }

    // Small grace period so the collector has certainly flushed.
    Timer {
        id: actionFinalize
        interval: 40
        onTriggered: root._finishAction()
    }

    // Safety net: if actionProc never starts, clear busy so the UI isn't
    // locked forever. Mirrors NetworkService.commandLaunchCheck.
    Timer {
        id: actionLaunchCheck
        interval: 500
        onTriggered: if (!actionProc.running && root.busy) root._finishAction()
    }

    function _startAction(kind, mac, script, args) {
        if (root.busy || actionProc.running) return false
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

        const raw = actionOut.text || ""
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

        const lower = out.toLowerCase()
        // Pairing often auto-connects, so the follow-up connect reports this.
        if (lower.includes("alreadyconnected") || lower.includes("already connected")) return

        if (rc === 124) {
            root.notify("Bluetooth Warning", "Timed out. Is the device on and in range?")
            return
        }
        if (rc === 0 && !/fail|error/i.test(out)) return

        // Older bluetoothctl exits 0 even on failure, hence the text check.
        // Show the one relevant line, not the whole transcript.
        const bad = lines.filter(l => /fail|error/i.test(l))
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
        return root._startAction("power", "",
            on ? "rfkill unblock bluetooth 2>/dev/null; timeout 15 bluetoothctl power on"
               : "timeout 15 bluetoothctl power off", [])
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

    // Safety net: if the scan process never starts, don't stay "Scanning..."
    Timer {
        interval: (root.scanSeconds + 4) * 1000
        running: root.scanning
        onTriggered: root.scanning = false
    }

    function scan() {
        if (!root.powered || scanProc.running) return
        root.scanning = true
        scanProc.running = true
    }

    Component.onCompleted: root.refresh()
}
