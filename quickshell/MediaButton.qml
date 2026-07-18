import QtQuick
import Quickshell.Io
import "."

Item {
    id: btn
    property string icon: ""
    property int size: 15
    property var command: []   // e.g. ["playerctl", "play-pause"]
    signal clicked()

    width: 32
    height: 32

    // FIX: single reusable Process instead of Qt.createQmlObject per click.
    // The old MusicWidget pattern created a brand-new Process object on
    // every play/pause/next/prev click and never destroyed it — a
    // permanent leak over a session.
    Process {
        id: proc
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: ma.containsPress
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
            : ma.containsMouse
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.icon
        color: Colors.surfaceFg
        font.pixelSize: btn.size
        font.family: "JetBrainsMono Nerd Font"
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (btn.command.length > 0 && !proc.running) {
                proc.command = btn.command
                proc.running = true
            }
            btn.clicked()
        }
    }
}
