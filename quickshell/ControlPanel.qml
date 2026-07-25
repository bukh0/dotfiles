import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: controlPanel

    // ❌ REMOVE THIS LINE entirely: keyboardFocus: KeyboardFocus.OnDemand

    property int barHeight: 42

    property bool isOpen: false
    property bool windowVisible: false
    visible: windowVisible
    color: "transparent"
    
    // ... [keep the rest of the file exactly the same] ...
    property int hoverCloseDelay: 300
    property int fadeOutDuration: 200
    property int openY: 46
    property int closedY: 26

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // THE FIX: Define the positive clickable space instead of subtracting.
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

    Rectangle {
        id: drawerBg
        width: 420
        height: contentCol.implicitHeight + 40
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        x: (parent.width - width) / 2
        y: controlPanel.isOpen ? controlPanel.openY : controlPanel.closedY
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        radius: 16
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1
        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
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
            }
            spacing: 16
            
            MusicWidget {}
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2) }
            VolumeSlider {}
            BrightnessSlider {}
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2) }
            SystemResourceRow {}
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2) }
            WifiToggle {}
            BluetoothToggle {}
            Item { height: 4 }
        }
    }
}
