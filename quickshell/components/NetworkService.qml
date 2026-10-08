pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool wifiOn: false
    property string ssid: ""
    property string connectionType: "none"
    property var networks: []
    property bool scanning: false
    property int signalStrength: 0
    property string activeWifiDevice: ""
    property string actionKind: ""
    property string targetSsid: ""
    readonly property bool busy: actionKind !== ""

    property string awaitingPasswordFor: ""
    property string _lastPasswordFailureSsid: ""
    property bool _statusErrorLogged: false

    signal connectionSettled()
    signal commandError(string message)
    onCommandError: message => Quickshell.execDetached(["notify-send", "-a", "Network", "--", "Wi-Fi Error", message])

    function signalIcon(sig) {
        if (sig >= 75) return "󰤨"
        if (sig >= 50) return "󰤥"
        if (sig >= 25) return "󰤢"
        return "󰤟"
    }

    // NetworkManager throttles back-to-back rescans. That message is harmless,
    // so it is logged instead of shown as a notification.
    function reportStderr(msg) {
        if (msg.length === 0) return
        if (/scanning not allowed/i.test(msg)) {
            console.warn("network:", msg)
            return
        }
        root.commandError(msg)
    }

    Process {
        id: cmdProc
        property bool started: false
        onStarted: { started = true; commandLaunchCheck.stop() }
        running: false
        stderr: StdioCollector {
            onStreamFinished: root.reportStderr(text.trim())
        }
        onRunningChanged: if (!running) root.finishCommand()
    }

    function finishCommand() {
        if (root.actionKind !== "command") return
        commandLaunchCheck.stop()
        root.actionKind = ""
        root.targetSsid = ""
        if (!cmdProc.started) root.commandError("Could not start network command")
        root.refresh()
        root.connectionSettled()
        root._drainMonitor()
    }

    Timer {
        id: commandLaunchCheck
        interval: 500
        onTriggered: if (!cmdProc.started && !cmdProc.running) root.finishCommand()
    }

    function clearStatus() {
        connectionType = "none"
        ssid = ""
        wifiOn = false
        signalStrength = 0
        activeWifiDevice = ""
        networks = []
    }

    // Returns true if the command was started, false if it was dropped
    // because another one is still running. Callers must only enter their
    // "in flight" state when this returns true; otherwise connectionSettled
    // never fires and the UI stays locked forever.
    function runCommand(cmd, commandSsid) {
        if (root.busy) return false
        root.targetSsid = commandSsid || ""
        root.actionKind = "command"
        cmdProc.started = false
        commandLaunchCheck.restart()
        cmdProc.command = cmd
        cmdProc.running = true
        return true
    }

    Process {
        id: statusPoll
        onExited: (code, status) => { if (code !== 0 || status !== 0) root.clearStatus() }
        // The wifi list is allowed to fail (no Wi-Fi device / radio off);
        // that must not stop ethernet detection from the device list.
        command: ["sh", "-c",
            "export LC_ALL=C\n" +
            "wifi=$(nmcli radio wifi) || exit 1\n" +
            "wifiList=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null) || wifiList=\n" +
            "devices=$(nmcli -t -f TYPE,STATE,DEVICE dev) || exit 1\n" +
            "printf '%s\\n%s\\n%s\\n' \"$wifi\" \"$wifiList\" \"$devices\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") { root.clearStatus(); return }
                root._statusErrorLogged = false
                const lines = text.trim().split("\n")
                root.wifiOn = (lines.length > 0 ? lines[0].trim() : "") === "enabled"

                let ssidFields = []
                let activeType = "none"
                let wifiDevice = ""
                for (let i = 1; i < lines.length; i++) {
                    const fields = root.parseNmcliFields(lines[i].trim())
                    if (fields.length >= 3 && fields[0] === "yes" && ssidFields.length === 0)
                        ssidFields = fields
                    if (fields.length === 3 && (fields[0] === "wifi" || fields[0] === "ethernet") && fields[1].startsWith("connected")) {
                        if (fields[0] === "ethernet") {
                            activeType = "ethernet"
                        } else if (fields[0] === "wifi") {
                            wifiDevice = fields[2]
                            if (activeType !== "ethernet") activeType = "wifi"
                        }
                    }
                }
                root.ssid = ssidFields.length >= 3 ? ssidFields[1] : ""
                root.signalStrength = ssidFields.length >= 3 ? (parseInt(ssidFields[2]) || 0) : 0
                root.connectionType = activeType
                root.activeWifiDevice = wifiDevice
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg.length > 0 && !root._statusErrorLogged) {
                    root._statusErrorLogged = true
                    console.warn("network status:", msg)
                }
            }
        }
        onRunningChanged: {
            if (!running) root._drainMonitor()
        }
    }

    property bool _monitorPending: false

    function refresh() {
        if (statusPoll.running) root._monitorPending = true
        else statusPoll.running = true
    }

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
        onTriggered: root.refresh()
    }

    Timer {
        id: nmStableTimer
        interval: 5000
        onTriggered: nmMonitor.restartDelay = 250
    }

    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: true
        property int restartDelay: 250
        stdout: SplitParser {
            onRead: (line) => {
                if (root._busy()) {
                    root._monitorPending = true
                    return
                }
                monitorDebounce.restart()
            }
        }
        onRunningChanged: {
            if (running) {
                nmStableTimer.restart()
                return
            }
            nmStableTimer.stop()
            nmMonitorRestart.interval = restartDelay
            nmMonitorRestart.restart()
            restartDelay = Math.min(restartDelay * 2, 30000)
        }
    }

    Timer {
        id: nmMonitorRestart
        interval: 250
        onTriggered: nmMonitor.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (!root._busy()) statusPoll.running = true
        }
        Component.onCompleted: statusPoll.running = true
    }

    function parseNmcliFields(line) {
        const fields = []
        let field = ""
        let escaped = false

        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escaped) {
                field += ch
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
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                const lines = text.split("\n").filter(l => l !== "")
                const seen = Object.create(null)
                for (const line of lines) {
                    const parts = root.parseNmcliFields(line)
                    if (parts.length < 4) continue
                    const name = parts[0]
                    if (!name) continue
                    const sig = parseInt(parts[1]) || 0
                    const active = parts[3] === "yes"

                    if (seen[name]) {
                        seen[name].active = seen[name].active || active
                        seen[name].signal = Math.max(seen[name].signal, sig)
                    } else {
                        seen[name] = {
                            ssid: name,
                            signal: sig,
                            security: parts[2] !== "" && parts[2] !== "--",
                            active: active
                        }
                    }
                }
                const parsed = Object.values(seen)
                parsed.sort((a, b) => Number(b.active) - Number(a.active) || b.signal - a.signal)
                root.networks = parsed.slice(0, 20)
                root.scanning = false
                if (root._scanPending) scanRestart.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.reportStderr(text.trim())
        }
        onRunningChanged: {
            if (running) return
            root.scanning = false
            if (root._scanPending) scanRestart.restart()
            root._drainMonitor()
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
        scanPoll.running = true
    }

    function toggleWifiRadio() {
        return runCommand(wifiOn ? ["nmcli", "radio", "wifi", "off"] : ["nmcli", "radio", "wifi", "on"])
    }

    Timer {
        id: connectSettledTimer
        interval: 0
        property int exitCode: 0
        onTriggered: {
            if (!connectProc._exited || !connectProc._stderrDone) return
            const stderrText = connectProc._stderrText
            if (exitCode === 0) {
                root.awaitingPasswordFor = ""
                root._lastPasswordFailureSsid = ""
            } else {
                const t = stderrText.toLowerCase()
                // Only the NM secrets error means "ask for a password". A bare
                // "password" match fires on SSIDs such as "password-net".
                if (t.includes("secrets were required")) {
                    const isRetry = root._lastPasswordFailureSsid === connectProc.targetSsid
                    root._lastPasswordFailureSsid = connectProc.targetSsid
                    root.awaitingPasswordFor = connectProc.targetSsid
                    if (isRetry) root.commandError("Incorrect password for " + connectProc.targetSsid)
                } else if (stderrText.trim().length > 0) {
                    // Any other failure used to vanish silently.
                    root.commandError(stderrText.trim())
                } else {
                    root.commandError("Could not connect to " + connectProc.targetSsid + " (exit " + exitCode + ").")
                }
            }
            root.actionKind = ""
            root.targetSsid = ""
            root.refresh()
            root.connectionSettled()
            root._drainMonitor()
        }
    }

    Process {
        id: connectProc
        property string targetSsid: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: connectStderr
            onStreamFinished: {
                connectProc._stderrText = text
                connectProc._stderrDone = true
                connectSettledTimer.restart()
            }
        }
        stdinEnabled: true
        onStarted: {
            connectProc._started = true
            if (connectProc._password !== "") connectProc.write(connectProc._password + "\n")
            // Don't keep the password around once it has been handed over.
            connectProc._password = ""
            // QProcess closes the write channel only after queued bytes flush.
            connectProc.stdinEnabled = false
        }
        onExited: (exitCode, exitStatus) => {
            connectProc._exited = true
            connectSettledTimer.exitCode = exitStatus === 0 ? exitCode : -1
            connectSettledTimer.restart()
        }
        onRunningChanged: {
            if (!running && root.actionKind === "connect") {
                connectProc._password = ""
                if (!connectProc._started) {
                    connectProc._exited = true
                    connectProc._stderrDone = true
                }
                connectSettledTimer.restart()
            }
        }
        property bool _started: false
        property bool _exited: false
        property bool _stderrDone: false
        property string _password: ""
        property string _stderrText: ""
    }

    // Returns true if the connect was started (see runCommand).
    function connectToNetwork(targetSsid, password) {
        if (root.busy) return false
        root.actionKind = "connect"
        root.targetSsid = targetSsid
        connectProc._started = false
        connectProc._exited = false
        connectProc._stderrDone = false
        connectSettledTimer.exitCode = -1
        connectProc.stdinEnabled = true
        connectProc.targetSsid = targetSsid
        connectProc._password = password || ""
        connectProc._stderrText = ""
        awaitingPasswordFor = ""
        connectProc.command = password
            ? ["env", "LC_ALL=C", "nmcli", "--wait", "30", "--ask", "dev", "wifi", "connect", targetSsid]
            : ["env", "LC_ALL=C", "nmcli", "--wait", "30", "dev", "wifi", "connect", targetSsid]
        connectProc.running = true
        return true
    }

    function disconnectActive() {
        if (root.activeWifiDevice === "") return false
        return runCommand(["nmcli", "dev", "disconnect", root.activeWifiDevice], root.ssid)
    }

    function cancelPasswordPrompt() {
        awaitingPasswordFor = ""
        _lastPasswordFailureSsid = ""
    }
}
