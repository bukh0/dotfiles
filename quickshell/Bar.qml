import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

PanelWindow {
    id: root

    // Use Top layer so fullscreen windows cover the bar
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        left: true
        right: true
    }

    // ── Dimensions ────────
    property int barHeight: 35
    property int pillRadius: 12
    property int pillPaddingH: 24        // 12px horizontal padding per side
    property int centerPillMinWidth: 180
    property int centerPillExtraWidth: 80

    // implicitHeight must fit barHeight + top/bottom margins (7 + 7),
    // otherwise pills overflow their container and get clipped.
    implicitHeight: barHeight + 14
    color: "transparent"

    property color pillBg: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.99)
    property color pillBorder: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

    // NOTE: the old Meta+F Shortcut block was removed — QML Shortcut only
    // fires if this layer-shell surface has keyboard focus, which a bar
    // shouldn't grab (it'd steal focus from whatever's active). Bind
    // fullscreen toggling natively in Hyprland instead:
    //   hl.bind({ mod = "SUPER", key = "F", dispatcher = hl.dsp.fullscreen })

    // ── Pill container ─────────────────────────────────────
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

                // --- Active Window Title ---
                Text {
                    id: activeWindowTitle

                    color: Colors.onSurface || "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Medium

                    // The Native Wayland hook
                    text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""

                    // Completely removes the element from layout when empty
                    visible: text !== ""

                    Layout.leftMargin: 12
                    Layout.maximumWidth: 350
                    elide: Text.ElideRight
                }
            }
        }

        // CENTER PILL – Clock & Control Panel trigger
        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight

            // Stable pill sizing so the clock doesn't jitter when time changes
            width: Math.max(centerLayout.implicitWidth + root.centerPillExtraWidth, root.centerPillMinWidth)

            radius: root.pillRadius
            border.width: 1

            // Tracks whether the panel was opened via click, as opposed to
            // hover — so a hover-exit can't slam shut a panel the user
            // deliberately pinned open.
            property bool pinnedOpen: false

            color: controlPanel.isOpen
                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                : centerMa.containsMouse
                ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
                : root.pillBg
            border.color: controlPanel.isOpen
                ? Colors.primary
                : root.pillBorder

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: centerLayout
                anchors.centerIn: parent
                Clock {}
            }

            MouseArea {
                id: centerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (!centerPill.pinnedOpen) controlPanel.beginHoverOpen()
                onExited: if (!centerPill.pinnedOpen) controlPanel.scheduleHoverClose()
                onClicked: {
                    centerPill.pinnedOpen = !centerPill.pinnedOpen
                    controlPanel.isOpen = centerPill.pinnedOpen
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

    // ── Overlays (attached directly) ────────────────────────
    ControlPanel {
        id: controlPanel
        openY: 10
        closedY: 26

        // Was root.implicitHeight (45, the whole window) — should reference
        // the actual visible pill height so the panel anchors correctly.
        barHeight: root.barHeight
    }

    NotificationDrawer {
        id: notificationDrawer
        drawerY: 10
    }
}
