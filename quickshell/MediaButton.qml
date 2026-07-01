import QtQuick
import "."

Item {
    id: btn
    property string icon: ""
    property int size: 15
    signal clicked()

    width: 32
    height: 32

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
        onClicked: btn.clicked()
    }
}
