import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 8

    property string title: "Nothing playing"
    property string artist: ""
    property string status: "Stopped"  // Playing, Paused, Stopped
    property bool playing: status === "Playing"

    // Poll playerctl every 2 seconds
    Process {
        id: metaPoll
        command: ["playerctl", "metadata", "--format", "{{title}}|{{artist}}|{{status}}"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                if (parts.length >= 3) {
                    title = parts[0] || "Nothing playing"
                    artist = parts[1] || ""
                    status = parts[2] || "Stopped"
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: metaPoll.running = true
    }

    // Title
    Text {
        Layout.fillWidth: true
        text: title
        color: Colors.surfaceFg
        font.pixelSize: 13
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    // Artist
    Text {
        Layout.fillWidth: true
        visible: artist !== ""
        text: artist
        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
        font.pixelSize: 11
        font.family: "JetBrainsMono Nerd Font"
        elide: Text.ElideRight
    }

    // Controls
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        // Previous
        MediaButton {
            icon: "󰒮"
            onClicked: {
                const p = Qt.createQmlObject('import Quickshell.Io; Process {}', parent)
                p.command = ["playerctl", "previous"]
                p.running = true
            }
        }

        // Play/Pause
        MediaButton {
            icon: playing ? "󰏤" : "󰐊"
            size: 18
            onClicked: {
                const p = Qt.createQmlObject('import Quickshell.Io; Process {}', parent)
                p.command = ["playerctl", "play-pause"]
                p.running = true
            }
        }

        // Next
        MediaButton {
            icon: "󰒭"
            onClicked: {
                const p = Qt.createQmlObject('import Quickshell.Io; Process {}', parent)
                p.command = ["playerctl", "next"]
                p.running = true
            }
        }

        Item { Layout.fillWidth: true }
    }
}
