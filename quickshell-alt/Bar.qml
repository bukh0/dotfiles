import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        left: true
        right: true
    }

    property int barHeight: 35
    property int pillRadius: 12
    property int pillPaddingH: 24
    property int centerPillMinWidth: 180
    property int centerPillExtraWidth: 80

    // The total height taken up by the bar + margins
    implicitHeight: barHeight + 14
    color: "transparent"

    property color pillBg: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.99)
    property color pillBorder: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

    Item {
        anchors.fill: parent
        anchors.margins: 7

        // ── LEFT PILL ──────────────────────────────────────────
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            width: leftLayout.implicitWidth + root.pillPaddingH

            radius: root.pillRadius
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1

            RowLayout {
                id: leftLayout
                anchors.centerIn: parent
                spacing: 0

                Workspaces { screen: root.screen }

                Text {
                    id: activeWindowTitle
                    color: Colors.surfaceFg
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    text: {
                        if (!ToplevelManager.activeToplevel) return ""
                        const raw = ToplevelManager.activeToplevel.title ?? ""
                        const parts = raw.split(" — ")
                        const name = parts[parts.length - 1].trim()
                        return name || raw
                    }
                    visible: text !== ""
                    Layout.leftMargin: 12
                    Layout.maximumWidth: 350
                    elide: Text.ElideRight
                }
            }
        }

        // ── CENTER PILL ────────────────────────────────────────
        Item {
            id: centerPillWrap
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: centerPill.width
            height: centerPill.height

            property bool pinnedOpen: false

            Pill {
                id: centerPill
                pillHeight: root.barHeight
                isActive: controlPanel.isOpen
                isHovered: centerMa.containsMouse
                width: Math.max(contentImplicitWidth + root.centerPillExtraWidth, root.centerPillMinWidth)

                Clock {}
            }

            MouseArea {
                id: centerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (!centerPillWrap.pinnedOpen) controlPanel.beginHoverOpen()
                onExited: if (!centerPillWrap.pinnedOpen) controlPanel.scheduleHoverClose()
                onClicked: {
                    centerPillWrap.pinnedOpen = !centerPillWrap.pinnedOpen
                    controlPanel.isOpen = centerPillWrap.pinnedOpen
                }
            }
        }

        // ── RIGHT PILL ─────────────────────────────────────────
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            width: rightLayout.implicitWidth + root.pillPaddingH

            radius: root.pillRadius
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1

            RowLayout {
                id: rightLayout
                anchors.centerIn: parent
                spacing: 13
                SystemTray {}
                NetworkIndicator {}
                BatteryIndicator {}
                NotificationBell {}
            }
        }
    }

    ControlPanel {
        id: controlPanel
        screen: root.screen
        // Drops the panel right below the total footprint of the floating bar
        openY: root.implicitHeight + 4
        // Pulls it up securely behind the mask when closed
        closedY: root.implicitHeight - 20
        // Tells the mask to start at the bottom of the floating boundary
        barHeight: root.implicitHeight
    }

    NotificationDrawer {
        id: notificationDrawer
        screen: root.screen
        drawerY: root.implicitHeight + 4
    }
}
