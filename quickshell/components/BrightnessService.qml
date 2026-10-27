pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ── BrightnessService ─────────────────────────────────────────────────────
// Owns backlight discovery, syncing and writing. Singleton so the device is
// discovered once at startup instead of on every panel open (the old
// per-open discovery made the slider pop in after the panel had opened).
//
// Touch it once at startup: shell.qml calls BrightnessService.discover().
Item {
    id: root

    // ── Public state ───────────────────────────────────────────────────
    property bool available: false
    property real brightness: 0.5     // 0..1, what the UI shows
    property string device: ""
    property int maxRaw: 0

    // Set by BrightnessSlider while it exists / while the user is dragging.
    property int watchers: 0
    property int interactions: 0
    readonly property bool interacting: interactions > 0
    readonly property int minimumRaw: Math.max(1, Math.ceil(maxRaw * 0.01))
    readonly property real minimum: maxRaw > 0 ? minimumRaw / maxRaw : 0.01

    readonly property int settleMs: 300   // quiet time before trusting a readback
    readonly property int pollMs: 1500    // fallback if sysfs never notifies

    // ── Internal ───────────────────────────────────────────────────────
    property int _wantedRaw: -1
    property int _lastSentRaw: -1
    property bool _errorMuted: false
    property bool _writeFinished: true
    property bool _writeStarted: false
    property int _readFailures: 0
    onDeviceChanged: { _readFailures = 0; readRetry.stop() }
    property bool _discoveryInFlight: false
    property int _discoveryAttempts: 0
    readonly property int discoveryRetryMs: Math.min(300000, 10000 * Math.pow(2, Math.max(0, _discoveryAttempts - 1)))
    onAvailableChanged: if (available) _discoveryAttempts = 0

    function _busy() {
        return root.interacting || !root._writeFinished || setProc.running || root._wantedRaw >= 0 || settleTimer.running
    }

    // ── Discovery: ask brightnessctl which device it will actually drive ──
    function discover() {
        if (root.available || root._discoveryInFlight) return
        root._discoveryInFlight = true
        discoverProc.started = false
        discoverProc.exited = false
        discoverProc.streamDone = false
        discoverProc.ok = false
        discoverProc.output = ""
        discoveryLaunchCheck.restart()
        _discoveryAttempts = Math.min(6, _discoveryAttempts + 1)
        discoverProc.running = true
    }

    function _finishDiscovery() {
        if (!root._discoveryInFlight) return
        if (!discoverProc.started) {
            if (discoverProc.running) return
        } else if (!discoverProc.exited || !discoverProc.streamDone) return
        discoveryLaunchCheck.stop()
        root._discoveryInFlight = false
        if (!discoverProc.started || !discoverProc.ok) return
        const f = discoverProc.output.trim().split("\n")[0].split(",")
        const max = Number(f[4])
        const cur = Number(f[2])
        if (f.length < 5 || f[0] === "" || !Number.isInteger(max) || max <= 0
                || f[2] === "" || !Number.isInteger(cur) || cur < 0) return
        root.device = f[0]
        root.maxRaw = max
        root.brightness = Math.min(1, cur / max)
        root.available = true
    }

    Timer { id: discoverySettled; interval: 0; onTriggered: root._finishDiscovery() }
    Timer {
        id: discoveryLaunchCheck
        interval: 500
        onTriggered: root._finishDiscovery()
    }
    Process {
        id: discoverProc
        property bool started: false
        property bool exited: false
        property bool streamDone: false
        property bool ok: false
        property string output: ""
        // Machine-readable: name,class,current,percent,max
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        onStarted: { started = true; discoveryLaunchCheck.stop() }
        onExited: (code, status) => {
            exited = true
            ok = code === 0 && status === 0
            discoverySettled.restart()
        }
        onRunningChanged: if (!running && !started) discoverySettled.restart()
        stdout: StdioCollector {
            onStreamFinished: {
                if (!discoverProc.started) return
                discoverProc.output = text
                discoverProc.streamDone = true
                discoverySettled.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!discoverProc.started) return
                const m = text.trim()
                if (m !== "") console.warn("brightness: discover:", m)
            }
        }
    }

    // ── Readback ───────────────────────────────────────────────────────
    FileView {
        id: brightFile
        // Match brightnessctl's writable setpoint. AMD's actual_brightness
        // can use a different scale and must not be fed back into this slider.
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        watchChanges: root.device !== ""
        onFileChanged: reload()
        onLoaded: {
            root._readFailures = 0
            readRetry.stop()
            // Ignore readbacks while we are writing or the user is dragging;
            // settleTimer triggers one authoritative re-read afterwards.
            if (root._busy()) return
            const v = parseInt(text())
            if (isNaN(v) || root.maxRaw <= 0) return
            root.brightness = Math.min(1, Math.max(0, v / root.maxRaw))
        }
        onLoadFailed: {
            if (root.device === "") return
            // Keep the known device through short sysfs read interruptions.
            // A successful read resets the budget, even during a write/drag.
            if (++root._readFailures <= 2) {
                readRetry.restart()
                return
            }
            readRetry.stop()
            root.available = false
            root.device = ""
            root.maxRaw = 0
            root._wantedRaw = -1
            root._lastSentRaw = -1
        }
    }

    Timer {
        id: readRetry
        interval: 200
        onTriggered: if (root.device !== "") brightFile.reload()
    }

    Timer {
        id: settleTimer
        interval: root.settleMs
        onTriggered: {
            root._lastSentRaw = -1
            brightFile.reload()
        }
    }

    // sysfs does not reliably emit file watcher events.
    Timer {
        interval: root.pollMs
        running: root.available && root.watchers > 0
        repeat: true
        onTriggered: if (!root._busy()) brightFile.reload()
    }

    Timer {
        // Missing backlights: retry after 10s, 20s, 40s... up to five minutes.
        interval: root.discoveryRetryMs
        running: !root.available
        repeat: true
        onTriggered: root.discover()
    }

    onWatchersChanged: {
        if (watchers <= 0) return
        if (!available) discover()
        else if (!_busy()) brightFile.reload()   // fresh value when the panel opens
    }

    onInteractingChanged: {
        if (!interacting) settleTimer.restart()
    }

    // ── Writing (single in-flight, latest value wins) ──────────────────
    // Raw values, not percentages: `set N%` rounds to hardware steps, so the
    // readback never matched the request and the slider snapped around.
    function request(value) {
        if (!root.available || root.maxRaw <= 0 || !isFinite(value)) return
        const raw = Math.min(root.maxRaw, Math.max(root.minimumRaw, Math.round(value * root.maxRaw)))
        root.brightness = raw / root.maxRaw
        if (raw === root._lastSentRaw && root._wantedRaw < 0) return
        root._wantedRaw = raw
        if (!writeTimer.running) writeTimer.start()
    }

    Timer {
        id: writeTimer
        interval: 40
        onTriggered: root._flush()
    }

    function _flush() {
        if (root._wantedRaw < 0 || !root._writeFinished || setProc.running) return
        const raw = root._wantedRaw
        root._wantedRaw = -1
        if (raw === root._lastSentRaw) return
        root._lastSentRaw = raw
        root._writeFinished = false
        root._writeStarted = false
        setProc.exited = false
        setProc.stderrDone = false
        setProc.errorText = ""
        setProc.exitCode = 0
        setProc.succeeded = false
        writeLaunchCheck.restart()
        settleTimer.stop()
        setProc.command = ["brightnessctl", "-q", "-d", root.device, "set", String(raw)]
        setProc.running = true
    }

    Timer { id: writeSettled; interval: 0; onTriggered: root._finishWrite() }
    Timer { id: writeLaunchCheck; interval: 500; onTriggered: root._finishWrite() }
    Process {
        id: setProc
        property bool exited: false
        property bool stderrDone: false
        property bool succeeded: false
        property int exitCode: 0
        property string errorText: ""
        onStarted: { root._writeStarted = true; writeLaunchCheck.stop() }
        onExited: (code, status) => {
            exitCode = code
            succeeded = code === 0 && status === 0
            exited = true
            writeSettled.restart()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (!root._writeStarted) return
                setProc.errorText = text.trim()
                setProc.stderrDone = true
                writeSettled.restart()
            }
        }
        onRunningChanged: if (!running) writeSettled.restart()
    }

    function _finishWrite() {
        if (root._writeFinished || setProc.running) return
        if (root._writeStarted && (!setProc.exited || !setProc.stderrDone)) return
        writeLaunchCheck.stop()
        if (!root._writeStarted || !setProc.succeeded) root._lastSentRaw = -1
        if (!root._writeStarted) root._reportError("Could not start brightnessctl.")
        else if (setProc.errorText !== "") {
            console.warn("brightness:", setProc.errorText)
            root._reportError(setProc.errorText)
        } else if (!setProc.succeeded)
            root._reportError("Could not set display brightness (exit " + setProc.exitCode + ").")
        root._writeFinished = true
        settleTimer.restart()
        if (root._wantedRaw >= 0) writeTimer.restart()
    }

    // One notification per burst, not one per failed write during a drag.
    function _reportError(msg) {
        if (root._errorMuted) return
        root._errorMuted = true
        errorMute.restart()
        Quickshell.execDetached(["notify-send", "-a", "Brightness", "--", "Brightness Error", msg])
    }

    Timer {
        id: errorMute
        interval: 5000
        onTriggered: root._errorMuted = false
    }
}
