import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

RowLayout {
    spacing: 12

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
        width: 64
        height: 64
        radius: 8
        color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
        clip: true

        Image {
            anchors.fill: parent
            source: artUrl
            fillMode: Image.PreserveAspectCrop
            visible: artUrl !== ""
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: artUrl === ""
            text: "󰎆"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            font.pixelSize: 24
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: title
            color: Colors.surfaceFg
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: artist !== "" || album !== ""
            text: artist + (artist !== "" && album !== "" ? " • " : "") + album
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            elide: Text.ElideRight
        }

        Item { height: 2 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MediaButton {
                icon: "󰒮"
                size: 19
                boxSize: 32
                command: ["playerctl", "previous"]
                onClicked: Qt.callLater(() => metaPoll.running = true)
            }

            MediaButton {
                icon: playing ? "󰏤" : "󰐊"
                size: 22
                boxSize: 36
                command: ["playerctl", "play-pause"]
                onClicked: Qt.callLater(() => metaPoll.running = true)
            }

            MediaButton {
                icon: "󰒭"
                size: 19
                boxSize: 32
                command: ["playerctl", "next"]
                onClicked: Qt.callLater(() => metaPoll.running = true)
            }

            Item { Layout.fillWidth: true }
        }
    }
}
