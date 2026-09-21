import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight

    property int capacity: 100
    property string status: "Unknown"
    property string battPath: ""

    readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    readonly property bool isCharging: status === "Charging" || status === "Full" || status === "Not charging"
    readonly property bool isCritical: !isCharging && capacity <= 10
    readonly property bool isLow: !isCharging && capacity <= 20

    readonly property string icon: {
        if (status === "Charging") return "󰂄"
        if (status === "Full" || status === "Not charging") return "󰚥"
        const idx = Math.min(9, Math.max(0, Math.floor(capacity / 10)))
        return icons[idx]
    }

    readonly property color iconColor: {
        if (isCharging) return Colors.primary
        if (isCritical) return Colors.error
        if (isLow) return Colors.tertiary
        return Colors.surfaceFg
    }

    // ── Resolve the battery's sysfs path once (BAT0 vs BAT1 etc.) ──
    Process {
        id: battDiscover
        command: ["sh", "-c", "ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p) root.battPath = p
            }
        }
    }

    function _parseUevent(content) {
        const lines = content.split("\n")
        for (const line of lines) {
            if (line.startsWith("POWER_SUPPLY_CAPACITY="))
                root.capacity = parseInt(line.split("=")[1]) || root.capacity
            else if (line.startsWith("POWER_SUPPLY_STATUS="))
                root.status = line.split("=")[1].trim() || root.status
        }
    }

    // ── Event-driven: the kernel emits a uevent (and thus an inotify
    // hit on this file) whenever capacity or charge status changes.
    FileView {
        id: uevent
        path: root.battPath !== "" ? root.battPath + "/uevent" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parseUevent(text())
    }

    // ── Fallback poll ────────────────────────────────────────
    // Backstop only, in case a driver doesn't emit uevents reliably.
    Process {
        id: battPoll
        command: ["sh", "-c", "cat " + root.battPath + "/capacity 2>/dev/null ; cat " + root.battPath + "/status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length >= 2) {
                    root.capacity = parseInt(lines[0]) || 0
                    root.status = lines[1].trim()
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: root.battPath !== ""
        repeat: true
        onTriggered: battPoll.running = true
    }

    SequentialAnimation {
        running: root.isCritical
        loops: Animation.Infinite
        NumberAnimation { target: label; property: "opacity"; to: 0.3; duration: 500 }
        NumberAnimation { target: label; property: "opacity"; to: 1.0; duration: 500 }
        onStopped: label.opacity = 1.0 
    }

    Text {
        id: label
        text: root.icon + " " + root.capacity + "%"
        color: root.iconColor
        font.pixelSize: 13
        font.family: Theme.fontMono
        font.weight: Font.Bold
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
