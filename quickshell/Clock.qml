import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    spacing: 6

    property string timeText: "00:00"
    property string dateText: "Mon 01 Jan"

    function updateTime() {
        let d = new Date()
        
        let h = d.getHours().toString()
        let m = d.getMinutes().toString()
        
        // ES5 safe zero-padding to avoid QML engine crashes
        timeText = (h.length < 2 ? "0" + h : h) + ":" + (m.length < 2 ? "0" + m : m)
        
        // Native Qt date formatting
        dateText = Qt.formatDateTime(d, "ddd dd MMM")
    }

    Timer {
        interval: 1000 
        running: true
        repeat: true
        onTriggered: updateTime()
        Component.onCompleted: updateTime()
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
