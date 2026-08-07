import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris // <-- Native MPRIS service
import "."

RowLayout {
    spacing: 8

    property string dateTimeText: "00:00 · ..."
    
    // OPTIMIZATION: Check if any active player is currently playing natively
    property bool isPlaying: {
        for (let i = 0; i < Mpris.players.length; ++i) {
            // Quickshell Mpris playbackState: 0 is Playing, 1 is Paused, 2 is Stopped
            if (Mpris.players[i].playbackState === 0) {
                return true
            }
        }
        return false
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            dateTimeText = Qt.formatDateTime(new Date(), "hh:mm · ddd - dd/MM/yyyy")
        }
        Component.onCompleted: triggered()
    }

    // Notice: We completely deleted the Process and the 2000ms Timer!

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
        text: dateTimeText
        color: Colors.primary
        font {
            pixelSize: 13
            family: "JetBrainsMono Nerd Font"
            weight: Font.Bold
        }
    }
}
