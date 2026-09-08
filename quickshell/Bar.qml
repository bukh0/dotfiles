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
    implicitHeight: 45
    color: "transparent"

    property int barHeight: 35
    property int pillRadius: 12

    property color pillBg: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.99)
    property color pillBorder: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)

    // ── HYPRLAND SHORTCUT ──────────────────────────────────
    Process {
        id: toggleFullscreen
        command: ["hyprctl", "dispatch", "fullscreen"]
    }

    Shortcut {
        sequence: "Meta+F"
        onActivated: {
            if (!toggleFullscreen.running) toggleFullscreen.running = true
        }
    }

    // ── Pill container ─────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: 7

        // LEFT PILL – Workspaces & Window Title
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            
            // Standardized to 24 (12px padding per side) for consistency
            width: leftLayout.implicitWidth + 24
            
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
                    
                    // THE FIX: Completely removes the element from layout when empty
                    visible: text !== ""
                    
                    // Since it hides when empty, we can just use a clean static margin here
                    Layout.leftMargin: 12 
                    Layout.maximumWidth: 350
                    elide: Text.ElideRight
                }
            }
        }

        // CENTER PILL – Clock & Control Panel trigger
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            
            // Stable pill sizing so the clock doesn't jitter when time changes
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

        // RIGHT PILL – System modules
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            
            // 24 (12px padding per side)
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
        
        barHeight: root.implicitHeight
    }

    NotificationDrawer {
        id: notificationDrawer
        drawerY: 10
    }
}
