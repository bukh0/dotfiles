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

    implicitHeight: barHeight + 14
    color: "transparent"

    property color pillBg: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.99)
    property color pillBorder: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

    // Fullscreen toggling is bound natively in Hyprland instead of a QML
    // Shortcut here, since a Shortcut only fires if this layer-shell
    // surface has keyboard focus — which a bar shouldn't grab:
    //   hl.bind({ mod = "SUPER", key = "F", dispatcher = hl.dsp.fullscreen })

    Item {
        anchors.fill: parent
        anchors.margins: 7

        // LEFT PILL – Workspaces & Window Title
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
                    text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""
                    visible: text !== ""
                    Layout.leftMargin: 12
                    Layout.maximumWidth: 350
                    elide: Text.ElideRight
                }
            }
        }

        // CENTER PILL – Clock & Control Panel trigger
        Item {
            id: centerPillWrap
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: centerPill.width
            height: centerPill.height

            // Tracks whether the panel was opened via click, as opposed to
            // hover — so a hover-exit can't slam shut a panel the user
            // deliberately pinned open.
            property bool pinnedOpen: false

            Pill {
                id: centerPill
                pillHeight: root.barHeight
                isActive: controlPanel.isOpen
                isHovered: centerMa.containsMouse

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

        // RIGHT PILL – System modules
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
        openY: 10
        closedY: 26
        barHeight: root.barHeight
    }

    NotificationDrawer {
        id: notificationDrawer
        drawerY: 10
    }
}
