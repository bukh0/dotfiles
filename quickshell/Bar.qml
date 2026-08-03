import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

PanelWindow {
    id: root
    
    // Changed from Overlay to Top so fullscreen applications cover the bar
    WlrLayershell.layer: WlrLayer.Top   

    anchors {
        top: true
        left: true
        right: true
    }

    height: 45
    color: "transparent"
    property int barHeight: 35
    property int pillRadius: 12

    property color pillBg: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.4)
    property color pillBorder: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

    // ==========================================
    // HYPRLAND SHORTCUT INTEGRATION
    // ==========================================
    Process {
        id: toggleFullscreen
        command: ["hyprctl", "dispatch", "fullscreen"]
    }

    Shortcut {
        sequence: "Meta+F"
        onActivated: toggleFullscreen.running = true
    }

    Item {
        anchors.fill: parent
        anchors.margins: 7

        // ==========================================
        // LEFT PILL — Workspaces
        // ==========================================
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            width: leftLayout.implicitWidth + 20
            radius: root.pillRadius
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            RowLayout {
                id: leftLayout
                anchors.centerIn: parent
                spacing: 0
                Workspaces { screen: root.screen }
            }
        }

        // ==========================================
        // CENTER PILL — Clock & Control Panel
        // ==========================================
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight

            // Increased the padding (+ 80) to stretch the central bar wider
            width: Math.max(centerLayout.implicitWidth + 80, 180)

            radius: root.pillRadius
            border.width: 1
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
                onEntered: controlPanel.beginHoverOpen()
                onExited: controlPanel.scheduleHoverClose()
                onClicked: controlPanel.isOpen = !controlPanel.isOpen
            }
        }

        // ==========================================
        // RIGHT PILL — System Modules
        // ==========================================
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            width: rightLayout.implicitWidth + 24
            radius: root.pillRadius
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1
            RowLayout {
                id: rightLayout
                anchors.centerIn: parent
                spacing: 13
                SystemTray {}
                NetworkIndicator {
                    onRequestPanelOpen: controlPanel.isOpen = true
                }
                BatteryIndicator {}
                NotificationBell {}
            }
        }
    }

    // ==========================================
    // OVERLAYS (Attached directly to the Bar)
    // ==========================================
    ControlPanel {
        id: controlPanel
        openY: 10
        closedY: 26
        barHeight: root.height
    }
    NotificationDrawer {
        id: notificationDrawer
        drawerY: 10
    }
}
