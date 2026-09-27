import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: root
    spacing: 6

    property real brightness: 0.5
    property string backlightPath: ""
    property real maxBrightness: 1
    property bool maxBrightnessReady: false

    readonly property string brightIcon: {
        if (slider.visualValue < 0.25) return "󰃞"
        if (slider.visualValue < 0.5)  return "󰃟"
        if (slider.visualValue < 0.75) return "󰃠"
        return "󰃠"
    }

    // ── Discover the backlight sysfs path once ──────────────────
    Process {
        id: backlightDiscover
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p) {
                    backlightPath = p
                    maxBrightProc.running = true
                }
            }
        }
    }

    // ── Read max_brightness once so we can normalise ────────────
    Process {
        id: maxBrightProc
        command: ["sh", "-c", "cat " + backlightPath + "/max_brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim())
                if (v > 0) {
                    maxBrightness = v
                    maxBrightnessReady = true
                } else {
                    // Don't mark ready on a bad read — that would leave
                    // maxBrightness stuck at its default of 1 and make
                    // every brightness value read back as ~100%. Retry
                    // instead of getting stuck.
                    console.warn("brightness: failed to read max_brightness, retrying")
                    maxBrightRetry.start()
                }
            }
        }
    }

    Timer {
        id: maxBrightRetry
        interval: 1000
        onTriggered: maxBrightProc.running = true
    }

    // ── inotify-based watch: kernel writes this file on every
    // hardware or software brightness change, so no polling needed.
    FileView {
        id: brightFile
        path: (backlightPath !== "" && maxBrightnessReady) ? backlightPath + "/brightness" : ""
        watchChanges: backlightPath !== "" && maxBrightnessReady
        onFileChanged: reload()
        onLoaded: {
            if (slider.isDragging) return   // ignore during drag
            const v = parseInt(text())
            if (!isNaN(v) && maxBrightness > 0)
                brightness = Math.min(1, Math.max(0.05, v / maxBrightness))
        }
    }

    Process {
        id: setProc
        property real pendingValue: 0
        property bool hasPendingValue: false

        onRunningChanged: {
            if (!running && hasPendingValue) {
                const next = pendingValue
                hasPendingValue = false
                command = ["brightnessctl", "set", Math.round(next * 100) + "%"]
                running = true
            }
        }
    }

    function setBrightness(value) {
        if (setProc.running) {
            setProc.pendingValue = value
            setProc.hasPendingValue = true
            return
        }
        setProc.command = ["brightnessctl", "set", Math.round(value * 100) + "%"]
        setProc.running = true
    }

    Timer {
        id: cmdDebounce
        interval: 75
        property real pending: 0
        onTriggered: {
            root.setBrightness(pending)
        }
    }

    SliderRow {
        id: slider
        icon: brightIcon
        iconColor: Colors.tertiary
        trackColor: Colors.tertiary
        value: brightness
        minValue: 0.05

        onDragged: val => {
            cmdDebounce.pending = val
            if (!cmdDebounce.running) cmdDebounce.start()
        }

        onCommitted: val => {
            brightness = val
            cmdDebounce.stop()
            root.setBrightness(val)
        }
    }
}
