import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real brightness: 0.5
    property real maxBrightness: 100

    property string brightIcon: {
        if (brightness < 0.25) return "󰃞"
        if (brightness < 0.5)  return "󰃟"
        if (brightness < 0.75) return "󰃠"
        return "󰃠"
    }

    Process {
        id: brightPoll
        command: ["sh", "-c", "brightnessctl get && brightnessctl max"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length >= 2) {
                    const cur = parseInt(lines[0])
                    const max = parseInt(lines[1])
                    if (max > 0) {
                        maxBrightness = max
                        brightness = cur / max
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: brightPoll.running = true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: brightIcon
            color: Colors.tertiary
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }

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
                    width: parent.width * brightness
                    height: parent.height
                    radius: 2
                    color: Colors.tertiary
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            Rectangle {
                x: brightness * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: Colors.tertiary
                Behavior on x { NumberAnimation { duration: 80 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                onClicked: mouse => setBrightness(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) setBrightness(mouse.x / width) }

                function setBrightness(val) {
                    val = Math.max(0.05, Math.min(1, val))
                    brightness = val
                    const p = Qt.createQmlObject('import Quickshell.Io; Process {}', parent)
                    p.command = ["brightnessctl", "set", Math.round(val * maxBrightness) + ""]
                    p.running = true
                }
            }
        }

        Text {
            text: Math.round(brightness * 100) + "%"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            Layout.minimumWidth: 32
        }
    }
}
