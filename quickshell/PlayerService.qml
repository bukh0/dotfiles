pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    // ── Public MPRIS state ────────────────────────────────────
    property string title: "Nothing playing"
    property string artist: ""
    property string album: ""
    property string status: "Stopped"
    property string artUrl: ""
    readonly property bool playing: status === "Playing"

    // ── Art cache (prevents blank flashes on track change) ────
    property string _lastArtUrl: ""

    // ── Playerctl polling ─────────────────────────────────────
    Process {
        id: metaPoll
        command: ["playerctl", "metadata", "--format",
                  "{{title}}\u001f{{artist}}\u001f{{album}}\u001f{{status}}\u001f{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err.length > 0) console.warn("playerctl:", err)
            }
        }
    }

    function _parse(raw) {
        const parts = raw.trim().split("\u001f")
        if (parts.length >= 4 && parts[0] !== "") {
            // Only update if values actually changed (reduces UI churn)
            const t = parts[0] || "Nothing playing"
            const a = parts[1] || ""
            const al = parts[2] || ""
            const s = parts[3] || "Stopped"
            const art = parts[4] || ""

            if (root.title !== t) root.title = t
            if (root.artist !== a) root.artist = a
            if (root.album !== al) root.album = al
            if (root.status !== s) root.status = s

            // Art URL: only update cache and property when necessary
            if (art !== "") {
                if (root._lastArtUrl !== art) root._lastArtUrl = art
                if (root.artUrl !== art) root.artUrl = art
            } else if (root.artUrl !== root._lastArtUrl) {
                // If new art is empty, fall back to cache, but only if different
                root.artUrl = root._lastArtUrl
            }
        } else {
            // No player active – reset to idle
            if (root.title !== "Nothing playing") root.title = "Nothing playing"
            if (root.artist !== "") root.artist = ""
            if (root.album !== "") root.album = ""
            if (root.status !== "Stopped") root.status = "Stopped"
            if (root.artUrl !== root._lastArtUrl) root.artUrl = root._lastArtUrl
        }
    }

    // ── Polling timer (runs only while application is active) ──
    Timer {
        id: pollTimer
        interval: 2000
        running: Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: {
            if (!metaPoll.running) metaPoll.running = true
        }
        Component.onCompleted: {
            // Immediately fetch if app is active, without double‑spawning
            if (Qt.application.state === Qt.ApplicationActive && !metaPoll.running)
                metaPoll.running = true
        }
    }

    // ── Manual refresh debounce (called after user actions) ────
    Timer {
        id: refreshDebounce
        interval: 80
        onTriggered: {
            if (!metaPoll.running) metaPoll.running = true
        }
    }

    function refresh() {
        refreshDebounce.restart()
    }
}
