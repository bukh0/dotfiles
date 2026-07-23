pragma Singleton
import QtQuick
import Quickshell.Io

// Shared MPRIS player state. Previously Clock.qml and MusicWidget.qml each
// ran their own independent `playerctl` poll every 2s — same data, two
// subprocess spawns. This centralizes it so both just bind to one source.
Item {
    id: root

    property string title: "Nothing playing"
    property string artist: ""
    property string album: ""
    property string status: "Stopped"
    property string artUrl: ""
    property bool playing: status === "Playing"

    // Unit separator (0x1f) instead of "|" as the field delimiter — a
    // track/artist name containing a literal "|" used to desync the fields.
    Process {
        id: metaPoll
        command: ["playerctl", "metadata", "--format", "{{title}}\u001f{{artist}}\u001f{{album}}\u001f{{status}}\u001f{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\u001f")
                if (parts.length >= 4 && parts[0] !== "") {
                    root.title = parts[0] || "Nothing playing"
                    root.artist = parts[1] || ""
                    root.album = parts[2] || ""
                    root.status = parts[3] || "Stopped"
                    root.artUrl = parts[4] || ""
                } else {
                    // playerctl prints nothing when no player is running
                    root.title = "Nothing playing"
                    root.artist = ""
                    root.album = ""
                    root.status = "Stopped"
                    root.artUrl = ""
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: metaPoll.running = true
        Component.onCompleted: metaPoll.running = true
    }

    // Call right after a play/pause/next/previous press so the widget
    // doesn't sit stale for up to 2s waiting on the next scheduled poll.
    function refresh() {
        Qt.callLater(() => metaPoll.running = true)
    }
}
