import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

RowLayout {
    spacing: 12

    property string title: "Nothing playing"
    property string artist: ""
    property string album: "" // Added property
    property string status: "Stopped"
    property string artUrl: ""
    property bool playing: status === "Playing"

    Process {
        id: metaPoll
        command: ["playerctl", "metadata", "--format", "{{title}}|{{artist}}|{{album}}|{{status}}|{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                // Increased length check to 4 to account for the new album field
                if (parts.length >= 4) {
                    title = parts[0] || "Nothing playing"
                    artist = parts[1] || ""
                    album = parts[2] || "" // Assigned value
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

    Process { id: actionProc }

    // Album Art Container
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

        // Updated Artist and Album line
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
            spacing: 12

            Text {
                text: "󰒮"
                color: prevMa.containsMouse ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        actionProc.command = ["playerctl", "previous"]
                        actionProc.running = true
                        Qt.callLater(() => metaPoll.running = true)
                    }
                }
            }

            Text {
                text: playing ? "󰏤" : "󰐊"
                color: playMa.containsMouse ? Colors.primary : Colors.surfaceFg
                font.pixelSize: 20
                font.family: "JetBrainsMono Nerd Font"
                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        actionProc.command = ["playerctl", "play-pause"]
                        actionProc.running = true
                        Qt.callLater(() => metaPoll.running = true)
                    }
                }
            }

            Text {
                text: "󰒭"
                color: nextMa.containsMouse ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        actionProc.command = ["playerctl", "next"]
                        actionProc.running = true
                        Qt.callLater(() => metaPoll.running = true)
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
