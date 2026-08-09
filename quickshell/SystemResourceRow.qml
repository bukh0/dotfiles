import QtQuick
import QtQuick.Controls          // ToolTip
import QtQuick.Layouts
import Quickshell.Io
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    // ── Fonts ──────────────────────────────────────────────
    property string uiFont: "sans-serif"
    property string iconFont: "JetBrainsMono Nerd Font"

    // ── Display values ─────────────────────────────────────
    property string cpuPercent: "0%"
    property string ramPercent: "0%"
    property string swapPercent: "0%"
    property string rxSpeed: "0 B/s"
    property string txSpeed: "0 B/s"
    property string powerProfile: "auto"
    property string cpuTemp: "--°C"
    property bool   cpuHot: false

    // ── Configuration ──────────────────────────────────────
    property int    tempWarningThreshold: 75   // °C – turns orange above this

    // Tooltip details
    property string tooltipRam: ""
    property string tooltipCpu: ""
    property string tooltipNet: "Calculating…"
    property string tooltipTemp: "Calculating…"
    property string tooltipProfile: ""
    property string cpuModel: ""

    // Delta tracking
    property real lastIdle: 0
    property real lastTotal: 0
    property real lastRx: 0
    property real lastTx: 0

    // ── Helpers ────────────────────────────────────────────
    function formatSpeed(bytes) {
        if (bytes < 1024) return bytes + " B/s"
        if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " KB/s"
        return (bytes / 1048576).toFixed(1) + " MB/s"
    }

    // ── CPU model (fetched once) ──────────────────────────
    Process {
        id: cpuInfoProc
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs"]
        stdout: StdioCollector {
            onStreamFinished: { root.cpuModel = text.trim() }
        }
    }
    Component.onCompleted: cpuInfoProc.running = true

    // ── Unified poll (awk) ─────────────────────────────────
    Process {
        id: statsPoll
        command: [
            "awk",
            '
            BEGIN { home = ENVIRON["HOME"]; temp = "N/A" }
            /^MemTotal:/     { mt = $2 }
            /^MemAvailable:/ { ma = $2 }
            /^SwapTotal:/    { st = $2 }
            /^SwapFree:/     { sf = $2 }
            /^cpu / { idle = $5; total = 0; for(i=2;i<=8;i++) total += $i }
            END {
                # Network: sum rx/tx for e* and w* interfaces
                while (getline < "/proc/net/dev") {
                    if ($1 ~ /^[ew]/) { rx += $2; tx += $10 }
                }
                close("/proc/net/dev")

                # Temperature – try zones 0‑9, then hwmon
                for (i = 0; i <= 9; i++) {
                    tfile = sprintf("/sys/class/thermal/thermal_zone%d/temp", i)
                    if ((getline t < tfile) > 0) { temp = int(t/1000); close(tfile); break }
                    close(tfile)
                }
                if (temp == "N/A") {
                    cmd = "ls /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1"
                    cmd | getline hwpath; close(cmd)
                    if (hwpath != "" && (getline t < hwpath) > 0) {
                        temp = int(t/1000); close(hwpath)
                    }
                    close(hwpath)
                }

                # Power profile
                pf = home "/.cache/perf-mode"
                if ((getline p < pf) > 0) profile = p; else profile = "auto"; close(pf)

                printf "ram %.0f %d %d %d %d\n", (mt ? (mt-ma)/mt*100 : 0), mt, ma, st, sf
                printf "cpu %d %d\n", idle, total
                printf "net %d %d\n", rx, tx
                printf "temp %s\n", temp
                printf "power %s\n", profile
            }' /proc/meminfo /proc/stat
        ]
        stdout: StdioCollector {
            onStreamFinished: root._parseStats(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err.length > 0) console.warn("statsPoll error:", err)
            }
        }
    }

    function _parseStats(raw) {
        const lines = raw.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (line.startsWith("ram ")) {
                const p = line.split(/\s+/)
                root.ramPercent = p[1] + "%"
                const swapTotal = parseInt(p[4]) || 0
                const swapFree  = parseInt(p[5]) || 0
                if (swapTotal > 0) {
                    root.swapPercent = Math.round((swapTotal - swapFree) / swapTotal * 100) + "%"
                } else {
                    root.swapPercent = "0%"
                }
                root.tooltipRam = `Total: ${Math.round(p[2] / 1024)} MB\nAvailable: ${Math.round(p[3] / 1024)} MB\nSwap: ${Math.round((swapTotal - swapFree) / 1024)} MB / ${Math.round(swapTotal / 1024)} MB`
            } else if (line.startsWith("cpu ")) {
                const p = line.split(/\s+/)
                const idle = parseFloat(p[1])
                const total = parseFloat(p[2])
                if (root.lastTotal > 0) {
                    const dIdle = idle - root.lastIdle
                    const dTotal = total - root.lastTotal
                    const usage = dTotal > 0 ? Math.round(100 * (1 - dIdle / dTotal)) : 0
                    root.cpuPercent = usage + "%"
                    root.tooltipCpu = `CPU: ${usage}%\n${root.cpuModel ? root.cpuModel : ""}`
                }
                root.lastIdle = idle
                root.lastTotal = total
            } else if (line.startsWith("net ")) {
                const p = line.split(/\s+/)
                const rx = parseInt(p[1]) || 0
                const tx = parseInt(p[2]) || 0
                if (root.lastRx > 0) {
                    root.rxSpeed = root.formatSpeed(Math.max(0, rx - root.lastRx) / 2)
                    root.txSpeed = root.formatSpeed(Math.max(0, tx - root.lastTx) / 2)
                    root.tooltipNet = `↓ ${root.rxSpeed}/s    ↑ ${root.txSpeed}/s`
                }
                root.lastRx = rx
                root.lastTx = tx
            } else if (line.startsWith("temp ")) {
                const p = line.split(/\s+/)
                root.cpuTemp = p[1] + "°C"
                const tval = parseInt(p[1])
                root.cpuHot = !isNaN(tval) && tval > root.tempWarningThreshold
                root.tooltipTemp = `Temperature: ${p[1]}°C` +
                    (root.cpuHot ? `\n⚠ Above ${root.tempWarningThreshold}°C` : "")
            } else if (line.startsWith("power ")) {
                const p = line.split(/\s+/)
                root.powerProfile = p[1] || "auto"
                root.tooltipProfile = `Power Profile: ${root.powerProfile}`
            }
        }
    }

    // ── Timer (pauses when app inactive) ──────────────────
    Timer {
        interval: 2000
        running: Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: {
            if (!statsPoll.running) statsPoll.running = true
        }
        Component.onCompleted: {
            if (Qt.application.state === Qt.ApplicationActive && !statsPoll.running)
                statsPoll.running = true
        }
    }

    // ── Flicker‑free tooltip helper ────────────────────────
    function delayedHideTooltip(tt) {
        if (tt.text !== "") hideTimer.trigger(tt)
        else tt.hide()
    }

    Timer {
        id: hideTimer
        interval: 100
        property var target: null
        onTriggered: { if (target) target.hide(); target = null }
        function trigger(t) { target = t; restart() }
    }

    // ── Reusable Stat (with tooltip) ──────────────────────
    component Stat: Item {
        property string icon: ""
        property string value: ""
        property string tooltipText: ""
        property color textColor: Colors.surfaceFg

        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Layout.alignment: Qt.AlignVCenter

        RowLayout {
            id: row
            spacing: 6
            Text {
                text: icon; color: textColor
                font.pixelSize: 15; font.family: root.iconFont; font.weight: Font.Bold
            }
            Text {
                text: value; color: textColor
                font.pixelSize: 12; font.family: root.uiFont; font.weight: Font.Bold
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered && tooltipText !== "") {
                    toolTip.show(tooltipText)
                } else {
                    root.delayedHideTooltip(toolTip)
                }
            }
        }

        ToolTip {
            id: toolTip
            text: ""
            delay: 300
            timeout: 2000
        }
    }

    // ── Divider ────────────────────────────────────────────
    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 12
        Layout.alignment: Qt.AlignVCenter
        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
    }

    // ── Layout ─────────────────────────────────────────────
    Stat { 
        icon: "󰍛"
        value: root.cpuPercent
        tooltipText: root.tooltipCpu
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8) 
    }
    Divider {}
    Stat { 
        icon: "󰆼"
        value: root.ramPercent + (root.swapPercent !== "0%" ? " / " + root.swapPercent : "")
        tooltipText: root.tooltipRam
        textColor: Colors.surfaceFg 
    }
    Divider {}
    Stat { 
        icon: "󰔏"
        value: root.cpuTemp
        tooltipText: root.tooltipTemp
        textColor: root.cpuHot ? "#ff8c00" : Colors.surfaceFg    // orange when hot
    }
    Divider {}
    Stat { 
        icon: "󰁅"
        value: root.rxSpeed
        tooltipText: root.tooltipNet          // same tooltip for both up/down
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65)
    }
    Stat { 
        icon: "󰁝"
        value: root.txSpeed
        tooltipText: root.tooltipNet          // shared tooltip
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65)
    }

    Item { Layout.fillWidth: true }

    // ── Power profile toggle ──────────────────────────────
    Item {
        Layout.preferredWidth: profileText.implicitWidth
        Layout.preferredHeight: profileText.implicitHeight
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: profileText
            text: root.powerProfile === "powersave" ? "󰌪" : (root.powerProfile === "performance" ? "󰓅" : "󰗑")
            color: root.powerProfile === "performance"
                ? Colors.error
                : (root.powerProfile === "powersave" ? Colors.tertiary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.9))
            font.pixelSize: 18
            font.family: root.iconFont
            font.weight: Font.Bold
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) toolTipProfile.show(root.tooltipProfile)
                else root.delayedHideTooltip(toolTipProfile)
            }
        }

        ToolTip { 
            id: toolTipProfile
            text: ""
            delay: 300
            timeout: 2000 
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (profileProc.running) return
                profileProc.command = ["bash", "-c", "~/.scripts/toggle-performance.sh"]
                profileProc.running = true
            }
        }
    }

    Process {
        id: profileProc
        onRunningChanged: {
            if (!running) statsPoll.running = true
        }
    }
}
