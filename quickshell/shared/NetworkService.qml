pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    // ── Public state ─────────────────────────────────────────
    property bool wifiOn: false
    property string ssid: ""
    property string connectionType: "none"   // "wifi", "ethernet", "none"
    property var networks: []
    property bool scanning: false
    property int signalStrength: 0

    // SSID that nmcli rejected for lacking a secret
    property string awaitingPasswordFor: ""

    // Tracks the SSID that most recently failed for a secrets/password
    // reason, independent of awaitingPasswordFor (which gets cleared at
    // the start of every attempt) — lets us tell a first-time prompt
    // apart from a second failed attempt.
    property string _lastPasswordFailureSsid: ""

    // ── Signals ──────────────────────────────────────────────
    signal connectionSettled()
    signal commandError(string message)

    // ── Shared icon-tier helper (used by WifiToggle + NetworkIndicator) ──
    function signalIcon(sig) {
        if (sig >= 75) return "󰤨"
        if (sig >= 50) return "󰤥"
        if (sig >= 25) return "󰤢"
        return "󰤟"
    }

    // ── Generic command runner ───────────────────────────────
    Process {
        id: cmdProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) root.commandError(msg)
            }
        }
        onRunningChanged: {
            if (!running) {
                statusPoll.running = true
                root.connectionSettled()
                root._drainMonitor()
            }
        }
    }

    function runCommand(cmd) {
        if (cmdProc.running) return
        cmdProc.command = cmd
        cmdProc.running = true
    }

    // ── Status poll (wifi state, ssid, signal, connection type) ──
    Process {
        id: statusPoll
        command: ["sh", "-c",
            "nmcli radio wifi ; " +
            "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes' | head -1 || true ; " +
            "nmcli -t -f TYPE,STATE dev | grep ':connected$' | head -1 | cut -d: -f1 || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.wifiOn = (lines[0]?.trim() === "enabled")

                const ssidFields = root.parseNmcliFields(lines[1]?.trim() || "")
                root.ssid = ssidFields.length >= 3 ? ssidFields[1] : ""
                root.signalStrength = ssidFields.length >= 3 ? (parseInt(ssidFields[2]) || 0) : 0

                const t = lines[2]?.trim()
                root.connectionType = t === "wifi" ? "wifi" : (t === "ethernet" ? "ethernet" : "none")
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) root.commandError(msg)
            }
        }
        onRunningChanged: {
            if (!running) root._drainMonitor()
        }
    }

    // ── Event-driven refresh ─────────────────────────────────
    // If nmcli monitor fires while something is already in flight, the
    // event used to just be dropped on the floor — whatever poll was
    // already running could have taken its snapshot before the change
    // landed. Now it's remembered and drained as soon as things are free,
    // instead of waiting on the next 10s fallback poll.
    property bool _monitorPending: false

    function _busy() {
        return cmdProc.running || connectProc.running || statusPoll.running || scanPoll.running
    }

    function _drainMonitor() {
        if (root._monitorPending && !root._busy()) {
            root._monitorPending = false
            monitorDebounce.restart()
        }
    }

    Timer {
        id: monitorDebounce
        interval: 150
        onTriggered: statusPoll.running = true
    }

    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                if (root._busy()) {
                    root._monitorPending = true
                    return
                }
                monitorDebounce.restart()
            }
        }
        // NOTE: this process is meant to live for the whole session.
        // Don't running=false/true-cycle it — restarting it drops nmcli
        // monitor's stream and you'll silently miss events until the
        // next fallback poll.
    }

    // ── Fallback poll ─────────────────────────────────────────
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!root._busy()) statusPoll.running = true
        }
        Component.onCompleted: statusPoll.running = true
    }

    // ── Scan for networks ────────────────────────────────────
    function parseNmcliFields(line) {
        const fields = []
        let field = ""
        let escaped = false

        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escaped) {
                field += ch === "n" ? "\n" : ch
                escaped = false
            } else if (ch === "\\") {
                escaped = true
            } else if (ch === ":") {
                fields.push(field)
                field = ""
            } else {
                field += ch
            }
        }
        if (escaped) field += "\\"
        fields.push(field)
        return fields
    }

    Process {
        id: scanPoll
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE dev wifi list | head -20"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                const lines = text.trim().split("\n").filter(l => l.trim() !== "")
                const seen = {}
                const parsed = []
                for (const line of lines) {
                    const parts = root.parseNmcliFields(line)
                    if (parts.length < 4) continue
                    const name = parts[0]
                    if (!name || seen[name]) continue
                    seen[name] = true
                    parsed.push({
                        ssid: name,
                        signal: parseInt(parts[1]) || 0,
                        security: parts[2] !== "--",
                        active: parts[3] === "yes"
                    })
                }
                parsed.sort((a, b) => b.signal - a.signal)
                root.networks = parsed
                root.scanning = false
                if (root._scanPending) scanRestart.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) root.commandError(msg)
            }
        }
    }

    property bool _scanPending: false

    Timer {
        id: scanRestart
        interval: 0
        onTriggered: {
            root._scanPending = false
            root.scan()
        }
    }

    function scan() {
        if (scanPoll.running) {
            root._scanPending = true
            root.scanning = true
            return
        }
        scanning = true
        networks = []
        scanPoll.running = true
    }

    function toggleWifiRadio() {
        runCommand(wifiOn ? ["nmcli", "radio", "wifi", "off"] : ["nmcli", "radio", "wifi", "on"])
    }

    // ── Connect / disconnect ─────────────────────────────────
    Process {
        id: connectProc
        property string targetSsid: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.toLowerCase()
                if (t.includes("secrets were required") ||
                    t.includes("no network with ssid") ||
                    t.includes("password")) {
                    const isRetry = root._lastPasswordFailureSsid === connectProc.targetSsid
                    root._lastPasswordFailureSsid = connectProc.targetSsid
                    root.awaitingPasswordFor = connectProc.targetSsid
                    if (isRetry) {
                        root.commandError("Incorrect password for " + connectProc.targetSsid)
                    }
                } else {
                    const msg = text.trim()
                    if (msg.length > 0) root.commandError(msg)
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                if (root.awaitingPasswordFor === "")
                    root._lastPasswordFailureSsid = ""
                statusPoll.running = true
                root.connectionSettled()
                root._drainMonitor()
            }
        }
    }

    function connectToNetwork(targetSsid, password) {
        if (connectProc.running) return
        connectProc.targetSsid = targetSsid
        awaitingPasswordFor = ""
        connectProc.command = password
            ? ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", targetSsid]
        connectProc.running = true
    }

    function disconnectActive() {
        runCommand(["sh", "-c",
            "nmcli dev disconnect \"$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -1)\""
        ])
    }

    function cancelPasswordPrompt() {
        awaitingPasswordFor = ""
        _lastPasswordFailureSsid = ""
    }
}
