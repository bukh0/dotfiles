import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: controlPanel

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property int barHeight: 42
    property bool isOpen: false
    property bool pinned: false
    property bool triggerHovered: false

    property int hoverCloseDelay: 560
    property int fadeOutDuration: 200
    property int slideDuration: 250
    property int openY: 46
    property int closedY: 26

    property int drawerWidth: Theme.drawerWidth
    property int drawerTopMargin: Theme.drawerPaddingV
    property int drawerBottomMargin: Theme.drawerPaddingV

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
        readonly property bool full: controlPanel.pinned || NetworkService.awaitingPasswordFor !== ""
        x: full ? 0 : hoverBridge.x
        y: controlPanel.barHeight
        width: !controlPanel.isOpen ? 0 : full ? controlPanel.width : hoverBridge.width
        height: !controlPanel.isOpen ? 0 : full ? controlPanel.height - controlPanel.barHeight : hoverBridge.height
    }

    Timer {
        id: closeDelayTimer
        interval: controlPanel.hoverCloseDelay
        onTriggered: {
            if (!controlPanel.pinned && !controlPanel.triggerHovered && !panelHover.hovered
                    && NetworkService.awaitingPasswordFor === "")
                controlPanel.isOpen = false
        }
    }

    Timer {
        id: fadeOutTimer
        interval: Math.max(controlPanel.slideDuration, controlPanel.fadeOutDuration)
        onTriggered: _fadingOut = false
    }

    onIsOpenChanged: {
        if (!isOpen) {
            pinned = false
            NetworkService.cancelPasswordPrompt()
        }
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
        if (!isOpen || pinned || triggerHovered || panelHover.hovered || NetworkService.awaitingPasswordFor !== "") return
        closeDelayTimer.restart()
    }

    function cancelHoverClose() {
        closeDelayTimer.stop()
    }

    // Keep pointer ownership below the bar throughout the slide animation.
    // Include the gap above the drawer so moving into it cannot start a close.
    Item {
        id: hoverBridge
        objectName: "controlPanelHoverBridge"
        z: 1
        x: (controlPanel.width - width) / 2
        y: controlPanel.barHeight
        width: Math.min(controlPanel.drawerWidth, Math.max(0, controlPanel.width - 16))
        height: Math.max(0, drawerBg.y + drawerBg.height)
        HoverHandler {
            id: panelHover
            enabled: controlPanel.isOpen
            onHoveredChanged: {
                if (hovered) controlPanel.cancelHoverClose()
                else controlPanel.scheduleHoverClose()
            }
        }
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

        // A window shortcut also receives Escape while a child text field
        // owns focus; a Keys handler on this sibling background does not.
        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: controlPanel.isOpen
            onActivated: controlPanel.isOpen = false
        }
    }

    Rectangle {
        id: drawerBg
        // The hover region must own the controls, not sit behind them as a
        // sibling: child hover handlers otherwise hide the pointer from it.
        parent: hoverBridge
        width: parent.width
        height: Math.min(contentLoader.implicitHeight + controlPanel.drawerTopMargin + controlPanel.drawerBottomMargin,
                         Math.max(0, controlPanel.height - controlPanel.openY - 8))

        y: (controlPanel.isOpen ? controlPanel.openY : controlPanel.closedY) - controlPanel.barHeight

        Behavior on height {
            enabled: controlPanel.isOpen
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: controlPanel.slideDuration; easing.type: Easing.OutQuart }
        }

        radius: Theme.panelRadius
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: controlPanel.fadeOutDuration }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        ScrollView {
            id: panelScroll
            anchors {
                fill: parent
                topMargin: controlPanel.drawerTopMargin
                bottomMargin: controlPanel.drawerBottomMargin
                leftMargin: Theme.drawerPaddingH
                rightMargin: Theme.drawerPaddingH
            }
            clip: true
            contentWidth: availableWidth
            contentHeight: contentLoader.implicitHeight
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Loader {
                id: contentLoader
                width: panelScroll.availableWidth
                active: controlPanel.isOpen || controlPanel._fadingOut
                sourceComponent: panelContent
            }
        }
    }

    Component {
        id: panelContent

        ColumnLayout {
            spacing: Theme.panelSpacing

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
