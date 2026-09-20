import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: controlPanel

    property int barHeight: 42
    property bool isOpen: false

    property int hoverCloseDelay: 300
    property int fadeOutDuration: 200
    property int slideDuration: 250
    property int openY: 46
    property int closedY: 26

    property int drawerWidth: 420
    property int drawerTopMargin: 20
    property int drawerBottomMargin: 24

    property bool _fadingOut: false

    visible: isOpen || _fadingOut

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

    Timer {
        id: closeDelayTimer
        interval: controlPanel.hoverCloseDelay
        onTriggered: controlPanel.isOpen = false
    }

    Timer {
        id: fadeOutTimer
        interval: Math.max(controlPanel.slideDuration, controlPanel.fadeOutDuration)
        onTriggered: _fadingOut = false
    }

    onIsOpenChanged: {
        if (isOpen) {
            _fadingOut = false
            closeDelayTimer.stop()
            fadeOutTimer.stop()
        } else {
            _fadingOut = true
            fadeOutTimer.restart()
        }
    }

    function beginHoverOpen() {
        closeDelayTimer.stop()
        isOpen = true
    }

    function scheduleHoverClose() {
        if (!isOpen) return
        closeDelayTimer.restart()
    }

    function cancelHoverClose() {
        closeDelayTimer.stop()
    }

    FocusScope {
        id: overlayScope
        anchors.fill: parent
        enabled: controlPanel.isOpen

        onEnabledChanged: {
            if (enabled) {
                Qt.callLater(() => {
                    if (overlayScope.enabled) overlayScope.forceActiveFocus()
                })
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: controlPanel.isOpen = false
        }

        Keys.onEscapePressed: controlPanel.isOpen = false
    }

    Rectangle {
        id: drawerBg
        width: controlPanel.drawerWidth
        height: contentCol.implicitHeight + controlPanel.drawerTopMargin + controlPanel.drawerBottomMargin

        x: (parent.width - width) / 2
        y: controlPanel.isOpen ? controlPanel.openY : controlPanel.closedY

        Behavior on y {
            NumberAnimation { duration: controlPanel.slideDuration; easing.type: Easing.OutQuart }
        }

        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: controlPanel.fadeOutDuration }
        }

        TapHandler {
            onTapped: {}
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    controlPanel.beginHoverOpen()
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
                margins: controlPanel.drawerTopMargin
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
