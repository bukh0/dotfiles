import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    spacing: 6

    property string timeText: "00:00"
    property string dateText: "Mon 01 Jan"

    Process {
        id: timePoll
        command: ["date", "+%H:%M"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: timeText = text.trim()
        }
    }

    Process {
        id: datePoll
        command: ["date", "+%a %d %b"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: dateText = text.trim()
        }
    }

    Timer {
        interval: 10000  // update every 10 seconds
        running: true
        repeat: true
        onTriggered: {
            timePoll.running = true
            datePoll.running = true
        }
    }

    Text {
        text: dateText
        color: Colors.surfaceFg
        font.pixelSize: 12
        font.family: "JetBrainsMono Nerd Font"
        opacity: 0.7
    }

    Text {
        text: timeText
        color: Colors.surfaceFg
        font.pixelSize: 13
        font.family: "JetBrainsMono Nerd Font"
        font.weight: Font.Medium
    }
}
