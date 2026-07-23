import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "."

RowLayout {
    spacing: 8

    property string timeText: "00:00"
    property string dateText: "..."
    property bool isPlaying: false

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let d = new Date()
            let h = d.getHours().toString()
            let m = d.getMinutes().toString()
            timeText = (h.length < 2 ? "0" + h : h) + ":" + (m.length < 2 ? "0" + m : m)
            dateText = Qt.formatDateTime(d, "ddd - dd/MM/yyyy")
        }
        Component.onCompleted: triggered()
    }

    Process {
        id: playerPoll
        command: ["playerctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                isPlaying = (text.trim() === "Playing")
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: playerPoll.running = true
        Component.onCompleted: playerPoll.running = true
    }

    Row {
        visible: isPlaying
        spacing: 2
        Layout.alignment: Qt.AlignVCenter

        component EqBar: Rectangle {
            property int minH: 4
            property int maxH: 10
            property int dur: 400

            width: 3
            height: minH
            radius: 1.5
            color: Colors.primary

            SequentialAnimation on height {
                running: isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: maxH; duration: dur; easing.type: Easing.InOutQuad }
                NumberAnimation { to: minH; duration: dur; easing.type: Easing.InOutQuad }
            }
        }

        EqBar { maxH: 9; dur: 350 }
        EqBar { maxH: 14; dur: 400 }
        EqBar { maxH: 10; dur: 450 }
    }

    Text {
        text: timeText + " · " + dateText
        color: Colors.primary
        font.pixelSize: 13
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Bold
    }
}
