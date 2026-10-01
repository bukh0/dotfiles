import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

RowLayout {
    id: root
    spacing: 8

    // ── Date / time ────────────────────────────────────────────
    property string dateTimeText: Qt.formatDateTime(clock.date, "hh:mm · ddd - dd/MM/yyyy")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: dateTimeText = Qt.formatDateTime(date, "hh:mm · ddd - dd/MM/yyyy")
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
