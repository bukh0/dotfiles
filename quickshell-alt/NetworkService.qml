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
            "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes' | cut -d: -f2- | head -1 || echo '' ; " +
            "nmcli -t -f TYPE,STATE dev | grep ':connected$' | head -1 | cut -d: -f1 || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.wifiOn = (lines[0]?.trim() === "enabled")

                // Field 2+ is "SSID:SIGNAL" joined by ':' — split from the
                // right so an SSID that itself contains ':' isn't mangled.
                const ssidSignal = (lines[1]?.trim() || "")
                const idx = ssidSignal.lastIndexOf(":")
                root.ssid = idx >= 0 ? ssidSignal.slice(0, idx) : ssidSignal
                root.signalStrength = idx >= 0 ? (parseInt(ssidSignal.slice(idx + 1)) || 0) : 0

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
    }

    // ── Event-driven refresh ─────────────────────────────────
    // nmcli monitor blocks and prints a line the instant NetworkManager's
    // state changes (radio toggle, connect, disconnect, IP change) — this
    // replaces polling as the primary trigger, so the bar updates in
    // ~150ms instead of waiting on a timer tick.
    Timer {
        id: monitorDebounce
        interval: 150
        // nmcli monitor often fires several lines for one real event
        // (device state change + connection activated, etc.) — debounce
        // so one event doesn't trigger multiple polls back to back.
        onTriggered: statusPoll.running = true
    }

    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                // Don't fight our own in-flight commands — they already
                // trigger a statusPoll via onRunningChanged when they finish.
                if (cmdProc.running || connectProc.running) return
                monitorDebounce.restart()
            }
        }
        // NOTE: this process is meant to live for the whole session.
        // Don't running=false/true-cycle it the way cmdProc is cycled —
        // restarting it drops nmcli monitor's stream and you'll silently
        // miss events until the next fallback poll.
    }

    // ── Fallback poll ─────────────────────────────────────────
    // Safety net only — catches things nmcli monitor won't emit an event
    // for, like RSSI drifting on an already-active connection. Interval is
    // long since this is a backstop, not the primary update path.
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!cmdProc.running) statusPoll.running = true
        }
        Component.onCompleted: statusPoll.running = true
    }

    // ── Scan for networks ────────────────────────────────────
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
                    const parts = line.split(":")
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
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0) root.commandError(msg)
            }
        }
    }

    function scan() {
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
                    root.awaitingPasswordFor = connectProc.targetSsid
                } else {
                    const msg = text.trim()
                    if (msg.length > 0) root.commandError(msg)
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                statusPoll.running = true
                root.connectionSettled()
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
        // Use a sub‑shell to avoid the double‑nmcli race when toggling
        runCommand(["sh", "-c",
            "nmcli dev disconnect \"$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -1)\""
        ])
    }

    function cancelPasswordPrompt() {
        awaitingPasswordFor = ""
    }
}
