import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real brightness: 0.5
    property string backlightPath: ""
    property real maxBrightness: 1

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
                if (v > 0) maxBrightness = v
            }
        }
    }

    // ── inotify-based watch: kernel writes this file on every
    // hardware or software brightness change, so no polling needed.
    FileView {
        id: brightFile
        path: backlightPath !== "" ? backlightPath + "/brightness" : ""
        watchChanges: backlightPath !== ""
        onFileChanged: reload()
        onLoaded: {
            if (slider.isDragging) return   // ignore during drag
            const v = parseInt(text())
            if (!isNaN(v) && maxBrightness > 0)
                brightness = Math.max(0.05, v / maxBrightness)
        }
    }

    Process { id: setProc }

    Timer {
        id: cmdDebounce
        interval: 75
        property real pending: 0
        onTriggered: {
            setProc.command = ["brightnessctl", "set", Math.round(pending * 100) + "%"]
            setProc.running = true
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
            setProc.command = ["brightnessctl", "set", Math.round(val * 100) + "%"]
            setProc.running = true
        }
    }
}
