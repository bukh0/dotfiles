import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: 84

    property string title: "Nothing playing"
    property string artist: ""
    property string album: ""
    property string status: "Stopped"
    property string artUrl: ""
    property bool playing: status === "Playing"

    Process {
        id: metaPoll
        command: ["playerctl", "metadata", "--format", "{{title}}|{{artist}}|{{album}}|{{status}}|{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                if (parts.length >= 4) {
                    title = parts[0] || "Nothing playing"
                    artist = parts[1] || ""
                    album = parts[2] || ""
                    status = parts[3] || "Stopped"
                    artUrl = parts[4] || ""
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

    Rectangle {
        id: art
        anchors.left: parent.left
        anchors.top: parent.top
        width: 84
        height: 84
        radius: 10
        color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
        clip: true

        Image {
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            visible: root.artUrl !== ""
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: "󰎆"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 30
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    ColumnLayout {
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Colors.surfaceFg
            font.pixelSize: 15
            font.family: "JetBrainsMono Nerd Font"
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.artist !== "" || root.album !== ""
            text: root.artist + (root.artist !== "" && root.album !== "" ? " • " : "") + root.album
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            elide: Text.ElideRight
        }
    }

    // Centered on the whole widget, independent of where the album art pushes the text column.
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 12

        MediaButton {
            icon: "󰒮"
            size: 21
            boxSize: 36
            command: ["playerctl", "previous"]
            onClicked: Qt.callLater(() => metaPoll.running = true)
        }

        MediaButton {
            icon: root.playing ? "󰏤" : "󰐊"
            size: 25
            boxSize: 42
            command: ["playerctl", "play-pause"]
            onClicked: Qt.callLater(() => metaPoll.running = true)
        }

        MediaButton {
            icon: "󰒭"
            size: 21
            boxSize: 36
            command: ["playerctl", "next"]
            onClicked: Qt.callLater(() => metaPoll.running = true)
        }
    }
}
