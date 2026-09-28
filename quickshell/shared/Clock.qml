import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "."

RowLayout {
    id: root
    spacing: 8

    // ── Date / time ────────────────────────────────────────────
    property string dateTimeText: Qt.formatDateTime(clock.date, "hh:mm · ddd - dd/MM/yyyy")

    readonly property bool isPlaying: Mpris.players.values.some(
        p => p.playbackState === MprisPlaybackState.Playing
    )

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: dateTimeText = Qt.formatDateTime(date, "hh:mm · ddd - dd/MM/yyyy")
    }

    // ── Equaliser animation ────────────────────────────────────
    Row {
        visible: isPlaying
        spacing: Theme.spacingXS / 2
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
                running: root.isPlaying && parent.visible
                loops: Animation.Infinite
                NumberAnimation { to: maxH; duration: dur; easing.type: Easing.InOutQuad }
                NumberAnimation { to: minH; duration: dur; easing.type: Easing.InOutQuad }
            }
        }

        EqBar { maxH: 9;  dur: 350 }
        EqBar { maxH: 14; dur: 400 }
        EqBar { maxH: 10; dur: 450 }
    }

    // ── Time display ───────────────────────────────────────────
    Text {
        text: dateTimeText
        color: Colors.primary
        font {
            pixelSize: Theme.fontSizeMD
            family: Theme.fontMono
            weight: Font.Bold
        }
    }
}
