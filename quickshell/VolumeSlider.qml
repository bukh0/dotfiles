import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real volume: 0.5
    property bool muted: false

    property string volIcon: {
        if (muted || volume === 0) return "󰝟"
        if (volume < 0.33) return "󰕿"
        if (volume < 0.66) return "󰖀"
        return "󰕾"
    }

    Process {
        id: volPoll
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // Output: "Volume: 0.50" or "Volume: 0.50 [MUTED]"
                const match = text.match(/Volume:\s+([\d.]+)/)
                if (match) volume = parseFloat(match[1])
                muted = text.includes("[MUTED]")
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: volPoll.running = true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: volIcon
            color: muted
                ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                : Colors.primary
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const p = Qt.createQmlObject('import Quickshell.Io; Process {}', parent)
                    p.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                    p.running = true
                    Qt.callLater(() => volPoll.running = true)
                }
            }
        }

        // Slider track
        Item {
            Layout.fillWidth: true
            height: 20

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

                Rectangle {
                    width: parent.width * Math.min(volume, 1.0)
                    height: parent.height
                    radius: 2
                    color: muted
                        ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)
                        : Colors.primary
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            // Drag handle
            Rectangle {
                x: Math.min(volume, 1.0) * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: Colors.primary
                Behavior on x { NumberAnimation { duration: 80 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                onClicked: mouse => setVolume(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) setVolume(mouse.x / width) }

                function setVolume(val) {
                    val = Math.max(0, Math.min(1, val))
                    volume = val
                    const p = Qt.createQmlObject('import Quickshell.Io; Process {}', parent)
                    p.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", val.toFixed(2)]
                    p.running = true
                }
            }
        }

        Text {
            text: Math.round(volume * 100) + "%"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            Layout.minimumWidth: 32
        }
    }
}
