import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: controlPanel

    // ── Configuration ─────────────────────────────────────────
    readonly property int barHeight: 42
    property bool isOpen: false

    property int hoverCloseDelay: 300
    property int fadeOutDuration: 200
    property int openY: 46
    property int closedY: 26

    property int drawerWidth: 420
    property int drawerTopMargin: 20
    property int drawerBottomMargin: 24

    // ── Visibility logic (clean binding, no one-shot overrides) ─
    // The window stays visible as long as the panel is open, or while the
    // fade-out animation is still running.
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

    // ── Timers ──────────────────────────────────────────────────
    Timer {
        id: closeDelayTimer
        interval: controlPanel.hoverCloseDelay
        onTriggered: controlPanel.isOpen = false
    }

    Timer {
        id: fadeOutTimer
        interval: controlPanel.fadeOutDuration
        onTriggered: _fadingOut = false
    }

    onIsOpenChanged: {
        if (isOpen) {
            _fadingOut = false
            closeDelayTimer.stop()
        } else {
            // Start fade-out visual, but keep window visible
            _fadingOut = true
            fadeOutTimer.restart()
        }
    }

    // ── Public API (called by the top bar or other components) ─
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

    // ── Background dismissal (click outside drawer / Escape) ─
    FocusScope {
        id: overlayScope
        anchors.fill: parent
        enabled: controlPanel.isOpen

        // Automatically grab keyboard focus when the panel appears
        onEnabledChanged: {
            if (enabled) overlayScope.focus = true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: controlPanel.isOpen = false
        }

        Keys.onEscapePressed: controlPanel.isOpen = false
    }

    // ── Visual drawer ─────────────────────────────────────────
    Rectangle {
        id: drawerBg
        width: controlPanel.drawerWidth
        height: contentCol.implicitHeight + controlPanel.drawerTopMargin + controlPanel.drawerBottomMargin

        x: (parent.width - width) / 2
        y: controlPanel.isOpen ? controlPanel.openY : controlPanel.closedY

        Behavior on y {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
        }

        radius: 16
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: controlPanel.fadeOutDuration }
        }

        // Keep the drawer open while the mouse hovers over it
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    controlPanel.beginHoverOpen()
                } else {
                    controlPanel.scheduleHoverClose()
                }
            }
        }

        // ── Content ────────────────────────────────────────────
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

    // ── Reusable divider ──────────────────────────────────────
    component Divider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
    }
}
