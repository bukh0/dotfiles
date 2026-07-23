import QtQuick
import Quickshell.Io
import "."

Item {
    id: btn
    property string icon: ""
    property int size: 17
    property int boxSize: 34
    property var command: []   // e.g. ["playerctl", "play-pause"]
    signal clicked()

    width: boxSize
    height: boxSize

    // Single reusable Process instead of creating one per click.
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
