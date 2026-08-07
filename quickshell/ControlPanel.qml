import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: controlPanel

    property int barHeight: 42
    property bool isOpen: false
    property bool windowVisible: false
    
    property int hoverCloseDelay: 300
    property int fadeOutDuration: 200
    property int openY: 46
    property int closedY: 26

    visible: windowVisible
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        x: 0
        y: controlPanel.barHeight
        width: controlPanel.width
        height: controlPanel.height - controlPanel.barHeight
    }

    onIsOpenChanged: {
        if (isOpen) {
            hideTimer.stop()
            windowVisible = true
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: controlPanel.fadeOutDuration
        onTriggered: controlPanel.windowVisible = false
    }

    Timer {
        id: closeTimer
        interval: controlPanel.hoverCloseDelay
        onTriggered: controlPanel.isOpen = false
    }

    function beginHoverOpen() {
        closeTimer.stop()
        isOpen = true
    }
    
    function scheduleHoverClose() {
        closeTimer.restart()
    }
    
    function cancelHoverClose() {
        closeTimer.stop()
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                if (typeof bgCloser !== "undefined") {
                    bgCloser.forceActiveFocus()
                }
            })
        }
    }

    MouseArea {
        id: bgCloser
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        enabled: controlPanel.isOpen
        Keys.onEscapePressed: controlPanel.isOpen = false
        onClicked: controlPanel.isOpen = false
    }

    // --- OPTIMIZATION: Reusable inline component for dividers ---
    component Divider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
    }

    Rectangle {
        id: drawerBg
        width: 420
        height: contentCol.implicitHeight + 40
        
        x: (parent.width - width) / 2
        y: controlPanel.isOpen ? controlPanel.openY : controlPanel.closedY
        
        // Only animate Y and Opacity (Height animation removed for performance)
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        
        radius: 16
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1
        
        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: controlPanel.fadeOutDuration } }

        // --- OPTIMIZATION: Lightweight TapHandler instead of MouseArea ---
        TapHandler {
            onTapped: {} // Consumes the click so it doesn't close the panel
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    controlPanel.isOpen = true
                } else {
                    controlPanel.scheduleHoverClose()
                }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 20
                bottomMargin: 24 // Added 4px here instead of creating a dummy Item{}
            }
            spacing: 16
            
            MusicWidget {}
            Divider {}
            VolumeSlider {}
            BrightnessSlider {}
            Divider {}
            SystemResourceRow {}
            Divider {}
            WifiToggle {}
            BluetoothToggle {}
        }
    }
}
