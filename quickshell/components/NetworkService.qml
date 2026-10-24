pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as Native

Item {
    id: root
    // Legacy transports remain available for isolated fixtures and diagnostics.
    // Normal operation reads status through native D-Bus property updates.
    property bool nativeStatusEnabled: true
    property bool _nativeReady: false
    readonly property var nativeSnapshot: {
        const devices = Native.Networking.devices.values
        const wifi = devices.filter(d => d.type === Native.DeviceType.Wifi && d.connected)
        let active = null, activeDevice = null
        for (const device of wifi) {
            const found = device.networks.values.find(n => n.connected)
            if (found) { active = found; activeDevice = device; break }
        }
        return {
            wifiOn: Native.Networking.wifiEnabled && Native.Networking.wifiHardwareEnabled,
            type: devices.some(d => d.type === Native.DeviceType.Wired && d.connected) ? "ethernet" : wifi.length ? "wifi" : "none",
            ssid: active ? active.name : "",
            strength: active ? Math.round(active.signalStrength * 100) : 0,
            device: activeDevice ? activeDevice.name : wifi.length ? wifi[0].name : ""
        }
    }
    onNativeSnapshotChanged: if (_nativeReady && nativeStatusEnabled) nativeSync.restart()
    Component.onCompleted: { _nativeReady = true; if (nativeStatusEnabled) refresh() }
    Timer { id: nativeSync; interval: 0; onTriggered: root.refresh() }
    function applyNativeStatus() {
        const state = nativeSnapshot
        wifiOn = state.wifiOn
        _radioOff = !state.wifiOn
        if (_radioOff) { networks = []; cancelPasswordPrompt() }
        connectionType = state.type
        ssid = state.ssid
        signalStrength = state.strength
        activeWifiDevice = state.device
    }


    property bool wifiOn: false
    property bool _radioOff: false
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
    property string awaitingPasswordScreen: ""
    property bool submittingPassword: false
    property string submittingPasswordScreen: ""
    onAwaitingPasswordForChanged: if (awaitingPasswordFor === "") awaitingPasswordScreen = ""
    onNetworksChanged: {
        if (awaitingPasswordFor !== "" && !networks.some(n => n.ssid === awaitingPasswordFor))
            cancelPasswordPrompt()
    }
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
        property bool _exited: false
        property bool _stderrDone: false
        property string _stderrText: ""
        property int _exitCode: 0
        property int _exitStatus: 0
        onStarted: { started = true; commandLaunchCheck.stop() }
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (!cmdProc.started) return // Failed spawns can retain old collector text.
                cmdProc._stderrText = text
                cmdProc._stderrDone = true
                commandSettled.restart()
            }
        }
        onExited: (code, status) => {
            cmdProc._exitCode = code
            cmdProc._exitStatus = status
            cmdProc._exited = true
            commandSettled.restart()
        }
        onRunningChanged: {
            if (!running && !started && root.actionKind === "command") {
                _exited = true
                _stderrDone = true
                commandSettled.restart()
            }
        }
    }

    // Finalize outside process signals: a settlement listener may start a new
    // command immediately, after both the exit and collector callbacks return.
    Timer {
        id: commandSettled
        interval: 0
        onTriggered: root.finishCommand()
    }

    function finishCommand() {
        if (root.actionKind !== "command" || !cmdProc._exited || !cmdProc._stderrDone) return
        commandLaunchCheck.stop()
        if (!cmdProc.started) root.commandError("Could not start network command")
        else if (cmdProc._stderrText.trim() !== "") root.reportStderr(cmdProc._stderrText.trim())
        else if (cmdProc._exitStatus !== 0) root.commandError("Network command crashed.")
        else if (cmdProc._exitCode !== 0) root.commandError("Network command failed (exit " + cmdProc._exitCode + ").")
        root.targetSsid = ""
        root.refresh()
        root.actionKind = ""
        root.connectionSettled()
        root._drainMonitor()
    }

    Timer {
        id: commandLaunchCheck
        interval: 500
        onTriggered: {
            if (!cmdProc.started && !cmdProc.running && root.actionKind === "command") {
                cmdProc._exited = true
                cmdProc._stderrDone = true
                commandSettled.restart()
            }
        }
    }

    function clearStatus() {
        // A failed poll is not evidence that the radio was switched off.
        // Keep scan rows (and any password field) until a confirmed update.
        connectionType = "none"
        ssid = ""
        signalStrength = 0
        activeWifiDevice = ""
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
        cmdProc._exited = false
        cmdProc._stderrDone = false
        cmdProc._stderrText = ""
        cmdProc._exitCode = 0
        cmdProc._exitStatus = 0
        commandSettled.stop()
        commandLaunchCheck.restart()
        cmdProc.command = cmd
        cmdProc.running = true
        return true
    }

    Process {
        id: statusPoll
        property bool started: false
        onStarted: { started = true; statusLaunchCheck.stop() }
        onExited: (code, status) => { if (code !== 0 || status !== 0) root.clearStatus() }
        // The wifi list is allowed to fail (no Wi-Fi device / radio off);
        // that must not stop ethernet detection from the device list.
        command: ["sh", "-c",
            "export LC_ALL=C\n" +
            "wifi=$(nmcli radio wifi) || exit 1\n" +
            "wifiList=$(nmcli -t -f ACTIVE,SSID,SIGNAL,DEVICE dev wifi list --rescan no 2>/dev/null) || wifiList=\n" +
            "devices=$(nmcli -t -f TYPE,STATE,DEVICE dev) || exit 1\n" +
            "printf '%s\\n%s\\n%s\\n' \"$wifi\" \"$wifiList\" \"$devices\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!statusPoll.started) return
                if (text.trim() === "") { root.clearStatus(); return }
                root._statusErrorLogged = false
                const lines = text.trim().split("\n")
                root.wifiOn = (lines.length > 0 ? lines[0].trim() : "") === "enabled"
                root._radioOff = !root.wifiOn
                if (root._radioOff) {
                    root.networks = []
                    root.cancelPasswordPrompt()
                }

                const activeNetworks = []
                const wifiDevices = []
                let activeType = "none"
                for (let i = 1; i < lines.length; i++) {
                    const fields = root.parseNmcliFields(lines[i])
                    if (fields.length === 4 && fields[0] === "yes")
                        activeNetworks.push(fields)
                    if (fields.length === 3 && (fields[0] === "wifi" || fields[0] === "ethernet") && fields[1].startsWith("connected")) {
                        if (fields[0] === "ethernet") {
                            activeType = "ethernet"
                        } else if (fields[0] === "wifi") {
                            wifiDevices.push(fields[2])
                            if (activeType !== "ethernet") activeType = "wifi"
                        }
                    }
                }
                // Keep the displayed SSID, signal and device from one connection.
                const ssidFields = activeNetworks.find(fields => wifiDevices.includes(fields[3])) || []
                root.ssid = ssidFields.length >= 3 ? ssidFields[1] : ""
                root.signalStrength = ssidFields.length >= 3 ? (parseInt(ssidFields[2]) || 0) : 0
                root.connectionType = activeType
                root.activeWifiDevice = ssidFields[3] || wifiDevices[0] || ""
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!statusPoll.started) return
                const msg = text.trim()
                if (msg.length > 0 && !root._statusErrorLogged) {
                    root._statusErrorLogged = true
                    console.warn("network status:", msg)
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                if (!started) {
                    statusLaunchCheck.stop()
                    root.clearStatus()
                }
                root._drainMonitor()
            }
        }
    }

    Timer {
        id: statusLaunchCheck
        interval: 500
        onTriggered: {
            if (!statusPoll.started && !statusPoll.running) {
                root.clearStatus()
                root._drainMonitor()
            }
        }
    }

    property bool _monitorPending: false

    function refresh() {
        if (nativeStatusEnabled) { applyNativeStatus(); return }
        if (statusPoll.running) root._monitorPending = true
        else {
            statusPoll.started = false
            statusLaunchCheck.restart()
            statusPoll.running = true
        }
    }

    function _busy() {
        return root.busy || cmdProc.running || connectProc.running || statusPoll.running || scanPoll.running
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
        onTriggered: {
            if (root._busy()) root._monitorPending = true
            else root.refresh()
        }
    }

    Timer {
        id: nmStableTimer
        interval: 5000
        onTriggered: nmMonitor.restartDelay = 250
    }

    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]
        running: !root.nativeStatusEnabled
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
            if (root.nativeStatusEnabled) return
            nmMonitorRestart.interval = restartDelay
            nmMonitorRestart.restart()
            restartDelay = Math.min(restartDelay * 2, 30000)
        }
    }

    Timer {
        id: nmMonitorRestart
        interval: 250
        onTriggered: if (!root.nativeStatusEnabled) nmMonitor.running = true
    }

    Timer {
        // nmcli monitor reports connection changes, not every signal change.
        // Read cached strength regularly without initiating Wi-Fi scans.
        interval: root.connectionType === "wifi" ? 10000 : 60000
        running: !root.nativeStatusEnabled
        repeat: true
        onTriggered: {
            if (!root._busy()) root.refresh()
        }
        Component.onCompleted: root.refresh()
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
        property string output: ""
        property bool stdoutDone: false
        property bool exited: false
        property bool succeeded: false
        property bool started: false
        onStarted: { started = true; scanLaunchCheck.stop() }
        onExited: (code, status) => {
            scanLaunchCheck.stop()
            exited = true
            succeeded = code === 0 && status === 0
            scanSettled.restart()
        }
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE,DEVICE", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                scanPoll.output = text
                scanPoll.stdoutDone = true
                scanSettled.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.reportStderr(text.trim())
        }
        onRunningChanged: {
            if (running) return
            if (!started) { exited = true; stdoutDone = true; succeeded = false }
            scanSettled.restart()
        }
    }

    Timer {
        id: scanLaunchCheck
        interval: 500
        onTriggered: {
            if (root.scanning && !scanPoll.started && !scanPoll.running) {
                scanPoll.exited = true
                scanPoll.stdoutDone = true
                scanPoll.succeeded = false
                scanSettled.restart()
            }
        }
    }

    function parseScan(text) {
        const lines = text.split("\n").filter(l => l !== "")
        const seen = Object.create(null)
        for (const line of lines) {
            const parts = root.parseNmcliFields(line)
            if (parts.length < 5) continue
            const name = parts[0]
            if (!name) continue
            const sig = parseInt(parts[1]) || 0
            const active = parts[3] === "yes"
            const device = parts[4]

            if (seen[name]) {
                seen[name].security = seen[name].security || (parts[2] !== "" && parts[2] !== "--")
                seen[name].active = seen[name].active || active
                seen[name].signal = Math.max(seen[name].signal, sig)
                if (active && device && !seen[name].activeDevices.includes(device))
                    seen[name].activeDevices.push(device)
            } else {
                seen[name] = {
                    ssid: name,
                    signal: sig,
                    security: parts[2] !== "" && parts[2] !== "--",
                    active: active,
                    activeDevices: active && device ? [device] : []
                }
            }
        }
        const parsed = Object.values(seen)
        parsed.sort((a, b) => Number(b.active) - Number(a.active) || b.signal - a.signal)
        const visible = parsed.slice(0, 20)
        // Keep the password field's row if a concurrent scan pushes it below
        // the display limit. An SSID absent from the full scan still cancels.
        const prompted = parsed.find(n => n.ssid === root.awaitingPasswordFor)
        if (prompted && !visible.includes(prompted)) visible[visible.length - 1] = prompted
        return visible
    }

    Timer {
        id: scanSettled
        interval: 0
        onTriggered: {
            if (!scanPoll.exited || !scanPoll.stdoutDone) return
            if (scanPoll.succeeded && !root._radioOff) root.networks = root.parseScan(scanPoll.output)
            scanLaunchCheck.stop()
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
        if (scanPoll.running || root.scanning) {
            root._scanPending = true
            root.scanning = true
            return
        }
        scanning = true
        scanPoll.output = ""
        scanPoll.stdoutDone = false
        scanPoll.exited = false
        scanPoll.succeeded = false
        scanPoll.started = false
        scanLaunchCheck.restart()
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
            if (root.actionKind !== "connect" || !connectProc._exited || !connectProc._stderrDone) return
            connectLaunchCheck.stop()
            connectProc._password = ""
            const stderrText = connectProc._stderrText
            if (!connectProc._started) {
                root.commandError("Could not start network connection")
            } else if (exitCode === 0) {
                root.awaitingPasswordFor = ""
                root._lastPasswordFailureSsid = ""
            } else {
                const t = stderrText.toLowerCase()
                // Only the NM secrets error means "ask for a password". A bare
                // "password" match fires on SSIDs such as "password-net".
                if (t.includes("secrets were required")) {
                    if (!connectProc._promptCancelled) {
                        const isRetry = root._lastPasswordFailureSsid === connectProc.targetSsid
                        root._lastPasswordFailureSsid = connectProc.targetSsid
                        root.awaitingPasswordScreen = connectProc.targetScreen
                        root.awaitingPasswordFor = connectProc.targetSsid
                        if (isRetry && connectProc._hadPassword) root.commandError("Incorrect password for " + connectProc.targetSsid)
                    }
                } else if (stderrText.trim().length > 0) {
                    // Any other failure used to vanish silently.
                    root.commandError(stderrText.trim())
                } else {
                    root.commandError("Could not connect to " + connectProc.targetSsid + " (exit " + exitCode + ").")
                }
            }
            root.actionKind = ""
            root.submittingPassword = false
            root.submittingPasswordScreen = ""
            root.targetSsid = ""
            root.refresh()
            root.connectionSettled()
            root._drainMonitor()
        }
    }

    Process {
        id: connectProc
        property string targetSsid: ""
        property string targetScreen: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: connectStderr
            onStreamFinished: {
                if (!connectProc._started) return
                connectProc._stderrText = text
                connectProc._stderrDone = true
                connectSettledTimer.restart()
            }
        }
        stdinEnabled: true
        onStarted: {
            connectProc._started = true
            connectLaunchCheck.stop()
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
        property bool _promptCancelled: false
        property bool _hadPassword: false
        property string _password: ""
        property string _stderrText: ""
    }

    Timer {
        id: connectLaunchCheck
        interval: 500
        onTriggered: {
            if (!connectProc._started && !connectProc.running && root.actionKind === "connect") {
                connectProc._exited = true
                connectProc._stderrDone = true
                connectSettledTimer.restart()
            }
        }
    }

    // Returns true if the connect was started (see runCommand).
    function connectToNetwork(targetSsid, password, screenName) {
        if (root.busy) return false
        root.actionKind = "connect"
        root.targetSsid = targetSsid
        connectProc._started = false
        connectProc._exited = false
        connectProc._stderrDone = false
        connectProc._promptCancelled = false
        connectSettledTimer.exitCode = -1
        connectProc.stdinEnabled = true
        connectProc.targetSsid = targetSsid
        connectProc.targetScreen = screenName || ""
        connectProc._password = password || ""
        connectProc._hadPassword = connectProc._password !== ""
        connectProc._stderrText = ""
        // Publish ownership before enabling the hold; preserve it across prompt removal.
        submittingPasswordScreen = connectProc._password !== "" ? connectProc.targetScreen : ""
        submittingPassword = connectProc._password !== ""
        awaitingPasswordFor = ""
        connectProc.command = password
            ? ["env", "LC_ALL=C", "nmcli", "--wait", "30", "--ask", "dev", "wifi", "connect", targetSsid]
            : ["env", "LC_ALL=C", "nmcli", "--wait", "30", "dev", "wifi", "connect", targetSsid]
        connectLaunchCheck.restart()
        connectProc.running = true
        return true
    }

    function disconnectActive(networkSsid) {
        if (networkSsid === undefined) {
            if (root.activeWifiDevice === "") return false
            return runCommand(["nmcli", "dev", "disconnect", root.activeWifiDevice], root.ssid)
        }
        const network = root.networks.find(n => n.ssid === networkSsid)
        let devices = network && Array.isArray(network.activeDevices) ? network.activeDevices : []
        // A connection status update can arrive before its scan row/device list.
        if (!devices.length && networkSsid === root.ssid && root.activeWifiDevice !== "")
            devices = [root.activeWifiDevice]
        if (!devices.length) return false
        // concat copies the device list; never mutate a scan row's shared array.
        return runCommand(["nmcli", "dev", "disconnect"].concat(devices), networkSsid)
    }

    function cancelPasswordPrompt(screenName) {
        if (screenName !== undefined
                && !(awaitingPasswordFor !== "" && screenName === awaitingPasswordScreen)
                && !(submittingPassword && screenName === submittingPasswordScreen)
                && !(actionKind === "connect" && screenName === connectProc.targetScreen)) return
        // Let the connection settle normally, but don't restore dismissed UI
        // when an in-flight request reports missing secrets later.
        if (actionKind === "connect") connectProc._promptCancelled = true
        awaitingPasswordFor = ""
        submittingPassword = false
        submittingPasswordScreen = ""
        _lastPasswordFailureSsid = ""
    }
}
