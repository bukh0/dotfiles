import QtQuick
import Quickshell.Io
import "."

Rectangle {
    id: btn
    
    // ── Properties ─────────────────────────────────────────
    property string icon: ""
    property int size: 17
    property int boxSize: 34
    property var command: []   // e.g. ["playerctl", "play-pause"]
    property string iconFont: "JetBrainsMono Nerd Font"

    signal clicked()

    // ── Dimensions & Styling ───────────────────────────────
    width: boxSize
    height: boxSize
    radius: 8

    // Visual feedback based on modern handler states
    color: tap.pressed
        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
        : hover.hovered
        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
        : "transparent"

    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: btn.icon
        color: Colors.surfaceFg
        font.pixelSize: btn.size
        font.family: btn.iconFont
    }

    // ── Command Execution ──────────────────────────────────
    Process {
        id: proc
    }

    // ── Interaction Handlers ───────────────────────────────
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        onTapped: {
            if (btn.command.length > 0) {
                // Allow rapid clicks (e.g., spamming "Next Track") 
                // by cleanly restarting the process if it's still running
                if (proc.running) {
                    proc.running = false
                }
                proc.command = btn.command
                proc.running = true
            }
            btn.clicked()
        }
    }
}
