pragma Singleton
import QtQuick
import Quickshell.Io

// Shared network state. Previously NetworkIndicator.qml and WifiToggle.qml
// each ran their own independent `nmcli` poll — same data, two subprocess
// chains on a timer. This centralizes status, scanning, and connect/disconnect
// (with a password-retry path nmcli needs but the old code never provided)
// in one place.
Item {
    id: root

    property bool wifiOn: false
    property string ssid: ""
    property string connectionType: "none"   // "wifi" | "ethernet" | "none"
    property var networks: []
    property bool scanning: false

    // SSID that nmcli rejected for lacking a secret — the UI should prompt
    // for a password for exactly this network.
    property string awaitingPasswordFor: ""

    signal connectionSettled()

    property var cmdProc: Process {
        id: cmdProc
        running: false
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

    // --- Status: wifi radio state, active SSID, and overall connection type ---
    Process {
        id: statusPoll
        command: ["sh", "-c",
            "nmcli radio wifi && " +
            "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2 | head -1 && " +
            "nmcli -t -f TYPE,STATE dev | grep connected | head -1 | cut -d: -f1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.wifiOn = lines[0]?.trim() === "enabled"
                root.ssid = lines[1]?.trim() || ""
                const t = lines[2]?.trim()
                root.connectionType = t === "wifi" ? "wifi" : (t === "ethernet" ? "ethernet" : "none")
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!cmdProc.running) statusPoll.running = true }
        Component.onCompleted: statusPoll.running = true
    }

    // --- Scan for nearby networks (only needed while the panel is expanded) ---
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
    }

    function scan() {
        scanning = true
        networks = []
        scanPoll.running = true
    }

    function toggleWifiRadio() {
        if (!wifiOn) {
            runCommand(["nmcli", "radio", "wifi", "on"])
            // No optimistic flip here — statusPoll (triggered by cmdProc
            // finishing) is what actually confirms the radio came on.
        }
    }

    // --- Connect / disconnect, with a password fallback for secured networks ---
    // nmcli fails quietly (no OS-level prompt) when a secured network isn't
    // already a known connection profile. We watch stderr for that failure
    // and ask the UI to show a password field instead of just leaving the
    // toggle showing a connection that never actually happened.
    //
    // NOTE: the exact nmcli wording used below ("secrets were required", "no
    // network with ssid") is a best-effort match against typical nmcli error
    // text — check it against what your nmcli version actually prints
    // (`nmcli dev wifi connect <ssid>` on a secured, unknown network from a
    // terminal) and adjust the match if it doesn't trigger.
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
        runCommand(["sh", "-c", "nmcli dev disconnect \"$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -1)\""])
    }

    function cancelPasswordPrompt() {
        awaitingPasswordFor = ""
    }
}
