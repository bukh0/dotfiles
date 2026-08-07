import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    spacing: 6

    property real volume: 0.5
    property bool muted: false
    
    property bool isDragging: volMa.pressed
    property real dragVolume: 0.5
    property real visualVolume: isDragging ? dragVolume : volume

    property string volIcon: {
        if (muted || visualVolume === 0) return "󰝟"
        if (visualVolume < 0.33) return "󰕿"
        if (visualVolume < 0.66) return "󰖀"
        return "󰕾"
    }

    Process {
        id: volPoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                const match = txt.match(/Volume:\s+([\d.]+)/)
                if (match) volume = parseFloat(match[1])
                muted = txt.includes("[MUTED]")
            }
        }
    }

    Timer {
        id: volPollTimer
        interval: 1000
        running: !isDragging
        repeat: true
        onTriggered: volPoll.running = true
        Component.onCompleted: volPoll.running = true
    }

    Process { id: ctlProc }
    Process { id: muteProc }

    Timer {
        id: cmdDebounce
        interval: 75
        onTriggered: {
            ctlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", dragVolume.toFixed(2)]
            ctlProc.running = true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: volIcon
            color: muted ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4) : Colors.primary
            font {
                pixelSize: 16
                family: "JetBrainsMono Nerd Font"
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: {
                    muteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                    muteProc.running = true
                    volPollTimer.restart()
                    Qt.callLater(() => volPoll.running = true)
                }
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
                    width: parent.width * Math.min(visualVolume, 1.0)
                    height: parent.height
                    radius: 2
                    color: muted ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4) : Colors.primary
                    Behavior on width { NumberAnimation { duration: isDragging ? 0 : 80 } }
                }
            }

            Rectangle {
                x: Math.min(visualVolume, 1.0) * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: Colors.primary
                Behavior on x { NumberAnimation { duration: isDragging ? 0 : 80 } }
            }

            MouseArea {
                id: volMa
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                
                onPressed: mouse => setVolume(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) setVolume(mouse.x / width) }
                onReleased: mouse => {
                    dragVolume = Math.max(0, Math.min(1, mouse.x / width))
                    volume = dragVolume // <--- FIX: Optimistic update prevents rubber-banding
                    cmdDebounce.stop()
                    
                    ctlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", dragVolume.toFixed(2)]
                    ctlProc.running = true
                    
                    volPollTimer.restart()
                }

                function setVolume(val) {
                    dragVolume = Math.max(0, Math.min(1, val))
                    volume = dragVolume // <--- FIX: Applied here too for fast clicks
                    if (!cmdDebounce.running) {
                        cmdDebounce.start()
                    }
                }
            }
        }

        Text {
            text: Math.round(Math.min(visualVolume, 1.0) * 100) + "%"
            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
            font {
                pixelSize: 11
                family: "JetBrainsMono Nerd Font"
            }
            Layout.minimumWidth: 32
        }
    }
}
