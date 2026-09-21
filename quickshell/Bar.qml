import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.94)

    // Bottom hairline separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, Theme.opacityHairline)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPaddingH
        anchors.rightMargin: Theme.barPaddingH

        // ── LEFT SECTION ───────────────────────────────────────
        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.barSectionGap

            Workspaces { screen: root.screen }

            Text {
                id: activeWindowTitle
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, Theme.opacityMuted)
                font.pixelSize: Theme.fontSizeBase
                font.family: Theme.fontMono
                font.weight: Font.Medium
                text: {
                    if (!ToplevelManager.activeToplevel) return ""
                    const raw = ToplevelManager.activeToplevel.title ?? ""
                    const parts = raw.split(" — ")
                    const name = parts[parts.length - 1].trim()
                    return name || raw
                }
                visible: text !== ""
                Layout.maximumWidth: 280
                elide: Text.ElideRight
            }
        }

        // ── CENTER SECTION ─────────────────────────────────────
        Item {
            id: centerWrap
            anchors.centerIn: parent
            width: centerBadge.width
            height: centerBadge.height
            property bool pinnedOpen: false

            Rectangle {
                id: centerBadge
                width: clockContent.implicitWidth + Theme.spacingXL
                height: 30
                radius: Theme.radius
                color: controlPanel.isOpen
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                    : centerMa.containsMouse
                    ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.08)
                    : "transparent"
                border.color: controlPanel.isOpen
                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)
                    : centerMa.containsMouse
                    ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.25)
                    : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Clock {
                    id: clockContent
                    anchors.centerIn: parent
                }
            }

            MouseArea {
                id: centerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (!centerWrap.pinnedOpen) controlPanel.beginHoverOpen()
                onExited: if (!centerWrap.pinnedOpen) controlPanel.scheduleHoverClose()
                onClicked: {
                    centerWrap.pinnedOpen = !centerWrap.pinnedOpen
                    controlPanel.isOpen = centerWrap.pinnedOpen
                }
            }
        }

        // ── RIGHT SECTION ──────────────────────────────────────
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMD

            SystemTray {}
            NetworkIndicator {}
            BatteryIndicator {}
            NotificationBell {}
        }
    }

    ControlPanel {
        id: controlPanel
        screen: root.screen
        openY: Theme.barHeight + 4
        closedY: Theme.barHeight - 14
        barHeight: Theme.barHeight
    }

    NotificationDrawer {
        id: notificationDrawer
        screen: root.screen
        drawerY: Theme.barHeight + 4
    }
}
