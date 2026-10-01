import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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

    property int barHeight: Theme.barHeight
    property int pillRadius: Theme.barPillRadius
    property int pillPaddingH: Theme.barPillPaddingH
    property int centerPillMinWidth: Theme.centerPillMinWidth
    property int centerPillExtraWidth: Theme.centerPillExtraWidth

    implicitHeight: Theme.floatingBar ? barHeight + Theme.barOuterMargin * 2 : barHeight
    color: Theme.floatingBar ? "transparent" : Colors.surface

    property color pillBg: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.99)
    property color pillBorder: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

    Rectangle {
        visible: !Theme.floatingBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, Theme.opacityHairline)
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.floatingBar ? Theme.barOuterMargin : 0

        Loader {
            anchors.fill: parent
            sourceComponent: Theme.floatingBar ? floatingBarComponent : classicBarComponent
        }
    }

    readonly property string activeTitle: {
        if (!ToplevelManager.activeToplevel || !Hyprland.focusedMonitor || !root.screen || Hyprland.focusedMonitor.name !== root.screen.name) return ""
        const raw = ToplevelManager.activeToplevel.title || ""
        return raw.split(" — ").pop().trim() || raw
    }

    component ClockInteraction: MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Timer {
            id: openDelay
            interval: 120
            onTriggered: if (interaction.containsMouse && !controlPanel.pinned) controlPanel.beginHoverOpen()
        }
        onEntered: openDelay.restart()
        onExited: { openDelay.stop(); if (!controlPanel.pinned) controlPanel.scheduleHoverClose() }
        onClicked: {
            openDelay.stop()
            controlPanel.pinned = !controlPanel.pinned
            controlPanel.isOpen = controlPanel.pinned
        }
    }

    Component {
        id: floatingBarComponent

        Item {
            anchors.fill: parent

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
                        textFormat: Text.PlainText
                        color: Colors.surfaceFg
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        text: root.activeTitle
                        visible: text !== ""
                        Layout.leftMargin: 12
                        Layout.maximumWidth: 350
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                id: centerPillWrap
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: centerPill.width
                height: centerPill.height
                Pill {
                    id: centerPill
                    pillHeight: root.barHeight
                    isActive: controlPanel.isOpen
                    isHovered: centerMa.containsMouse
                    width: Math.max(contentImplicitWidth + root.centerPillExtraWidth, root.centerPillMinWidth)
                    Clock {}
                }

                ClockInteraction { id: centerMa }
            }

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
                    NotificationBell { screen: root.screen }
                }
            }
        }
    }

    Component {
        id: classicBarComponent

        Item {
            anchors.fill: parent

            RowLayout {
                id: classicLeft
                anchors {
                    left: parent.left
                    leftMargin: Theme.barPaddingH
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.barSectionGap

                Workspaces { screen: root.screen }

                Text {
                    textFormat: Text.PlainText
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, Theme.opacityMuted)
                    font.pixelSize: Theme.fontSizeBase
                    font.family: Theme.fontMono
                    font.weight: Font.Medium
                    text: root.activeTitle
                    visible: text !== ""
                    Layout.maximumWidth: 280
                    elide: Text.ElideRight
                }
            }

            Item {
                id: classicClockWrap
                anchors.centerIn: parent
                width: classicClock.implicitWidth
                height: classicClock.implicitHeight
                Clock {
                    id: classicClock
                    anchors.fill: parent
                }

                ClockInteraction {}
            }

            RowLayout {
                id: classicRight
                anchors {
                    right: parent.right
                    rightMargin: Theme.barPaddingH
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.barSectionGap
                SystemTray {}
                NetworkIndicator {}
                BatteryIndicator {}
                NotificationBell { screen: root.screen }
            }
        }
    }

    ControlPanel {
        id: controlPanel
        screen: root.screen
        openY: Theme.barTotalHeight + 4
        closedY: Theme.floatingBar ? root.implicitHeight - 20 : root.implicitHeight - 14
        barHeight: root.implicitHeight
    }
}
