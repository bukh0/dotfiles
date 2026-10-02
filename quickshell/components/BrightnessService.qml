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
    property bool _writeFinished: false
    property bool _writeStarted: false

    function _busy() {
        return root.interacting || setProc.running || root._wantedRaw >= 0 || settleTimer.running
    }

    // ── Discovery: ask brightnessctl which device it will actually drive ──
    function discover() {
        if (root.available || discoverProc.running) return
        discoverProc.running = true
    }

    Process {
        id: discoverProc
        // Machine-readable: name,class,current,percent,max
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",")
                const max = parseInt(f[4])
                const cur = parseInt(f[2])
                if (f.length < 5 || f[0] === "" || !(max > 0)) return
                root.device = f[0]
                root.maxRaw = max
                if (!isNaN(cur)) root.brightness = Math.min(1, Math.max(0, cur / max))
                root.available = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
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
            // Ignore readbacks while we are writing or the user is dragging;
            // settleTimer triggers one authoritative re-read afterwards.
            if (root._busy()) return
            const v = parseInt(text())
            if (isNaN(v) || root.maxRaw <= 0) return
            root.brightness = Math.min(1, Math.max(0, v / root.maxRaw))
        }
        onLoadFailed: {
            root.available = false
            root.device = ""
            root.maxRaw = 0
            root._wantedRaw = -1
            root._lastSentRaw = -1
        }
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
        interval: 10000
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
        if (root._wantedRaw < 0 || setProc.running) return
        const raw = root._wantedRaw
        root._wantedRaw = -1
        if (raw === root._lastSentRaw) return
        root._lastSentRaw = raw
        root._writeFinished = false
        root._writeStarted = false
        settleTimer.stop()
        setProc.command = ["brightnessctl", "-q", "-d", root.device, "set", String(raw)]
        setProc.running = true
    }

    Process {
        id: setProc
        onStarted: root._writeStarted = true
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                root._lastSentRaw = -1
                root._reportError("Could not set display brightness (exit " + exitCode + ").")
            }
            root._finishWrite()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim()
                if (msg === "") return
                console.warn("brightness:", msg)
                root._reportError(msg)
            }
        }
        onRunningChanged: {
            if (!running && !root._writeStarted) {
                root._lastSentRaw = -1
                root._reportError("Could not start brightnessctl.")
                root._finishWrite()
            }
        }
    }

    function _finishWrite() {
        if (root._writeFinished) return
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
