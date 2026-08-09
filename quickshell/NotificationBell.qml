import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    property int count: NotificationDaemon.notifications ? NotificationDaemon.notifications.length : 0
    property bool hasNotifs: count > 0
    
    // ── Fonts ──────────────────────────────────────────────
    property string uiFont: "sans-serif"
    property string iconFont: "JetBrainsMono Nerd Font"

    // ── Dimensions & Styling ───────────────────────────────
    // Added padding for a comfortable button-like hit area
    implicitWidth: row.implicitWidth + 16
    implicitHeight: row.implicitHeight + 8
    radius: 6

    // Subtle background highlight on hover
    color: hover.hovered ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.1) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.hasNotifs ? "󰂚" : "󰂜"
            color: root.hasNotifs ? Colors.primary : Colors.surfaceFg
            font.pixelSize: 16
            font.family: root.iconFont

            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: root.hasNotifs
            text: root.count
            color: Colors.primary
            font.pixelSize: 12
            font.weight: Font.Bold
            font.family: root.uiFont
        }
    }

    // ── Interaction Handlers ───────────────────────────────
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                NotificationDaemon.beginHoverOpen()
            } else {
                NotificationDaemon.scheduleHoverClose()
            }
        }
    }

    TapHandler {
        onTapped: NotificationDaemon.toggleDrawer()
    }
}
