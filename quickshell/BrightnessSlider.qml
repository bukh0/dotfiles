import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real brightness: 0.5
    
    property bool isDragging: brightMa.pressed
    property real dragBright: 0.5
    property real visualBright: isDragging ? dragBright : brightness

    property string brightIcon: {
        if (visualBright < 0.25) return "󰃞"
        if (visualBright < 0.5)  return "󰃟"
        if (visualBright < 0.75) return "󰃠"
        return "󰃠"
    }

    Process {
        id: brightPoll
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",")
                if (parts.length >= 4) {
                    brightness = parseFloat(parts[3].replace("%", "")) / 100.0
                }
            }
        }
    }

    Timer {
        id: brightPollTimer
        interval: 2000
        running: !isDragging
        repeat: true
        onTriggered: brightPoll.running = true
        Component.onCompleted: brightPoll.running = true
    }

    Process { id: setProc }

    Timer {
        id: cmdDebounce
        interval: 75
        onTriggered: {
            setProc.command = ["brightnessctl", "set", Math.round(dragBright * 100) + "%"]
            setProc.running = true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: brightIcon
            color: Colors.tertiary
            font {
                pixelSize: 16
                family: "JetBrainsMono Nerd Font"
            }
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
                    width: parent.width * visualBright
                    height: parent.height
                    radius: 2
                    color: Colors.tertiary
                    Behavior on width { NumberAnimation { duration: isDragging ? 0 : 80 } }
                }
            }

            Rectangle {
                x: visualBright * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: Colors.tertiary
                Behavior on x { NumberAnimation { duration: isDragging ? 0 : 80 } }
            }

            MouseArea {
                id: brightMa
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                
                onPressed: mouse => setBrightness(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) setBrightness(mouse.x / width) }
                onReleased: mouse => {
                    dragBright = Math.max(0.05, Math.min(1, mouse.x / width))
                    brightness = dragBright // <--- FIX: Optimistic update
                    cmdDebounce.stop()
                    
                    setProc.command = ["brightnessctl", "set", Math.round(dragBright * 100) + "%"]
                    setProc.running = true
                    
                    brightPollTimer.restart()
                }

                function setBrightness(val) {
                    dragBright = Math.max(0.05, Math.min(1, val))
                    brightness = dragBright // <--- FIX: Applied here too
                    if (!cmdDebounce.running) {
                        cmdDebounce.start()
                    }
                }
            }
        }

        Text {
            text: Math.round(visualBright * 100) + "%"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
            font {
                pixelSize: 11
                family: "JetBrainsMono Nerd Font"
            }
            Layout.minimumWidth: 32
        }
    }
}
