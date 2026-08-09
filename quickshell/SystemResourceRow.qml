import QtQuick
import QtQuick.Controls          
import QtQuick.Layouts
import Quickshell.Io
import "."

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8 // Reduced spacing to fit the drawer comfortably

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
    property int    tempWarningThreshold: 75

    property string tooltipRam: ""
    property string tooltipCpu: ""
    property string tooltipNet: "Calculating…"
    property string tooltipTemp: "Calculating…"
    property string tooltipProfile: ""
    property string cpuModel: ""

    property real lastIdle: 0
    property real lastTotal: 0
    property real lastRx: 0
    property real lastTx: 0
    property var  lastNetTime: 0

    // ── Helpers ────────────────────────────────────────────
    function formatSpeed(bytes) {
        // Shortened suffixes to save horizontal space in the panel
        if (bytes < 1024) return bytes.toFixed(0) + " B/s"
        if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " K/s"
        return (bytes / 1048576).toFixed(1) + " M/s"
    }

    // ── CPU model (fetched once) ──────────────────────────
    Process {
        id: cpuInfoProc
        command: ["sh", "-c", "awk -F: '/model name/ { gsub(/^[ \\t]+/, \"\", $2); print $2; exit }' /proc/cpuinfo"]
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
            `
            BEGIN { home = ENVIRON["HOME"]; temp = "N/A" }
            /^MemTotal:/     { mt = $2 }
            /^MemAvailable:/ { ma = $2 }
            /^SwapTotal:/    { st = $2 }
            /^SwapFree:/     { sf = $2 }
            /^cpu / { idle = $5; total = 0; for(i=2;i<=8;i++) total += $i }
            END {
                while ((getline < "/proc/net/dev") > 0) {
                    if ($1 ~ /^[ew]/) { rx += $2; tx += $10 }
                }
                close("/proc/net/dev")

                for (i = 0; i <= 9; i++) {
                    tfile = "/sys/class/thermal/thermal_zone" i "/temp"
                    if ((getline t < tfile) > 0) { temp = int(t/1000); close(tfile); break }
                    close(tfile)
                }
                if (temp == "N/A") {
                    cmd = "cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1"
                    if ((cmd | getline t) > 0) temp = int(t/1000)
                    close(cmd)
                }

                pf = home "/.cache/perf-mode"
                if ((getline p < pf) > 0) profile = p; else profile = "auto"; 
                close(pf)

                print "ram", (mt ? (mt-ma)/mt*100 : 0), mt+0, ma+0, st+0, sf+0
                print "cpu", idle+0, total+0
                print "net", rx+0, tx+0
                print "temp", temp
                print "power", profile
            }
            `, 
            "/proc/meminfo", 
            "/proc/stat"
        ]
        stdout: StdioCollector {
            onStreamFinished: root._parseStats(text)
        }
    }

    function _parseStats(raw) {
        const lines = raw.trim().split("\n")
        const now = Date.now()

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const p = line.split(/\s+/)
            
            if (line.startsWith("ram ")) {
                root.ramPercent = Math.round(parseFloat(p[1])) + "%"
                const swapTotal = parseInt(p[4]) || 0
                const swapFree  = parseInt(p[5]) || 0
                
                root.swapPercent = swapTotal > 0 ? Math.round((swapTotal - swapFree) / swapTotal * 100) + "%" : "0%"
                root.tooltipRam = `Total: ${Math.round(p[2] / 1024)} MB\nAvailable: ${Math.round(p[3] / 1024)} MB\nSwap: ${Math.round((swapTotal - swapFree) / 1024)} MB / ${Math.round(swapTotal / 1024)} MB`
            
            } else if (line.startsWith("cpu ")) {
                const idle = parseFloat(p[1]) || 0
                const total = parseFloat(p[2]) || 0
                
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
                const rx = parseInt(p[1]) || 0
                const tx = parseInt(p[2]) || 0
                
                if (root.lastNetTime > 0) {
                    const dt = (now - root.lastNetTime) / 1000.0
                    if (dt > 0) {
                        root.rxSpeed = root.formatSpeed(Math.max(0, rx - root.lastRx) / dt)
                        root.txSpeed = root.formatSpeed(Math.max(0, tx - root.lastTx) / dt)
                        root.tooltipNet = `↓ ${root.rxSpeed}    ↑ ${root.txSpeed}`
                    }
                }
                root.lastRx = rx
                root.lastTx = tx
                root.lastNetTime = now
                
            } else if (line.startsWith("temp ")) {
                let tval = parseInt(p[1])
                if (!isNaN(tval)) {
                    if (tval > 1000) tval = Math.round(tval / 1000)
                    root.cpuTemp = tval + "°C"
                    root.cpuHot = tval > root.tempWarningThreshold
                    root.tooltipTemp = `Temperature: ${tval}°C` + (root.cpuHot ? `\n⚠ Above ${root.tempWarningThreshold}°C` : "")
                } else {
                    root.cpuTemp = "N/A"
                }
                
            } else if (line.startsWith("power ")) {
                root.powerProfile = p[1] || "auto"
                root.tooltipProfile = `Power Profile: ${root.powerProfile}`
            }
        }
    }

    Timer {
        interval: 2000
        running: Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: { if (!statsPoll.running) statsPoll.running = true }
        Component.onCompleted: { if (Qt.application.state === Qt.ApplicationActive && !statsPoll.running) statsPoll.running = true }
    }

    // ── Reusable Stat (Scalable) ──────────────────────────
    component Stat: RowLayout {
        id: statRoot
        property string icon: ""
        property string value: ""
        property string tooltipText: ""
        property color textColor: Colors.surfaceFg

        // CRITICAL FIX: Allows children to shrink and elide instead of breaking layout bounds
        Layout.minimumWidth: 0
        Layout.fillWidth: true
        
        spacing: 6

        Text {
            text: statRoot.icon
            color: statRoot.textColor
            font.pixelSize: 15; font.family: root.iconFont; font.weight: Font.Bold
        }
        Text {
            text: statRoot.value
            color: statRoot.textColor
            font.pixelSize: 12; font.family: root.uiFont; font.weight: Font.Bold
            
            // CRITICAL FIX: Ensure the text safely truncates if the drawer gets too crowded
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        HoverHandler { id: hoverHandler }

        ToolTip.visible: hoverHandler.hovered && statRoot.tooltipText !== ""
        ToolTip.text: statRoot.tooltipText
        ToolTip.delay: 300
        ToolTip.timeout: 2000
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
        // Dropped inline swap string to save horizontal space (it's still in the ToolTip)
        value: root.ramPercent
        tooltipText: root.tooltipRam
        textColor: Colors.surfaceFg 
    }
    Divider {}
    
    Stat { 
        icon: "󰔏"
        value: root.cpuTemp
        tooltipText: root.tooltipTemp
        textColor: root.cpuHot ? "#ff8c00" : Colors.surfaceFg 
    }
    Divider {}
    
    Stat { 
        icon: "󰁅"
        value: root.rxSpeed
        tooltipText: root.tooltipNet
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65) 
    }
    Stat { 
        icon: "󰁝"
        value: root.txSpeed
        tooltipText: root.tooltipNet
        textColor: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.65) 
    }

    // Expands to push the power profile toggle flush against the right wall
    Item { 
        Layout.fillWidth: true
        Layout.minimumWidth: 0 
    }

    // ── Power profile toggle ──────────────────────────────
    RowLayout {
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

            HoverHandler { id: profileHover }

            ToolTip.visible: profileHover.hovered && root.tooltipProfile !== ""
            ToolTip.text: root.tooltipProfile
            ToolTip.delay: 300
            ToolTip.timeout: 2000 

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (profileProc.running) return
                    profileProc.command = ["bash", "-c", "~/.scripts/toggle-performance.sh"]
                    profileProc.running = true
                }
            }
        }
    }

    Process {
        id: profileProc
        onRunningChanged: {
            if (!running && !statsPoll.running) {
                statsPoll.running = true
            }
        }
    }
}
