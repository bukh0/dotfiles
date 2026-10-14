import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: controlPanel

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: controlPanel.isOpen && controlPanel.heldByUser ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property int barHeight: 42
    property bool isOpen: false
    property bool pinned: false
    property bool triggerHovered: false
    property string outputName: ""
    property real clockTriggerWidth: Theme.centerPillMinWidth + 12
    property real clockTriggerBottom: barHeight
    readonly property bool hasPasswordPrompt: NetworkService.awaitingPasswordFor !== ""
                                               && NetworkService.awaitingPasswordScreen === outputName
    readonly property bool passwordSubmissionInProgress: NetworkService.submittingPassword
                                                        && NetworkService.submittingPasswordScreen === outputName
    readonly property bool heldByUser: pinned || hasPasswordPrompt || passwordSubmissionInProgress
    onHeldByUserChanged: {
        if (heldByUser) cancelHoverClose()
        else scheduleHoverClose()
    }

    property int hoverCloseDelay: 510
    property int fadeOutDuration: 200
    property int slideDuration: 250
    property int openY: 46
    property int closedY: 26

    property int drawerWidth: Theme.drawerWidth
    property int hoverEdgePadding: 18
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
        readonly property bool full: controlPanel.heldByUser
        x: full ? 0 : hoverGuard.x
        y: full ? controlPanel.barHeight : hoverGuard.y
        width: !controlPanel.isOpen ? 0 : full ? controlPanel.width : hoverGuard.width
        height: !controlPanel.isOpen ? 0 : full ? controlPanel.height - controlPanel.barHeight : hoverGuard.height
    }

    Timer {
        id: closeDelayTimer
        interval: controlPanel.hoverCloseDelay
        onTriggered: {
            if (!controlPanel.heldByUser && !controlPanel.triggerHovered && !panelHover.hovered)
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
            NetworkService.cancelPasswordPrompt(outputName)
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
        if (!isOpen || heldByUser || triggerHovered || panelHover.hovered) return
        closeDelayTimer.restart()
    }

    function cancelHoverClose() {
        closeDelayTimer.stop()
    }

    // Match the input mask to the padded hover area, including the bar seam.
    Item {
        id: hoverGuard
        objectName: "controlPanelHoverGuard"
        z: 1
        x: (controlPanel.width - width) / 2
        y: Math.max(0, Math.floor(Math.min(controlPanel.barHeight - 2, controlPanel.clockTriggerBottom - 1)))
        width: Math.min(controlPanel.drawerWidth + controlPanel.hoverEdgePadding * 2,
                        Math.max(0, controlPanel.width - 16))
        height: hoverBridge.height + hoverBridge.y
        MouseArea {
            // The overlapping strip receives clicks instead of the clock below it.
            // Give those clicks the same pin action as clicking the clock itself.
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, controlPanel.clockTriggerWidth)
            height: hoverBridge.y
            z: 1
            enabled: controlPanel.isOpen && !controlPanel.heldByUser
            cursorShape: Qt.PointingHandCursor
            onClicked: controlPanel.pinned = true
        }
        // Child hover handlers are nonblocking so both their feedback and
        // this ancestor observer receive hover; no overlay sits above controls.
        HoverHandler {
            id: panelHover
            blocking: false
            enabled: controlPanel.isOpen
            onHoveredChanged: if (hovered) controlPanel.cancelHoverClose()
                              else controlPanel.scheduleHoverClose()
        }
        Item {
            id: hoverBridge
            objectName: "controlPanelHoverBridge"
            x: (parent.width - width) / 2
            y: controlPanel.barHeight - hoverGuard.y
            width: Math.min(controlPanel.drawerWidth, Math.max(0, controlPanel.width - 16))
            readonly property real targetDrawerHeight: Math.min(
                contentLoader.implicitHeight + controlPanel.drawerTopMargin + controlPanel.drawerBottomMargin,
                Math.max(0, controlPanel.height - controlPanel.openY - 8))
            height: controlPanel.isOpen
                    ? Math.max(0, controlPanel.openY - controlPanel.barHeight + targetDrawerHeight) : 0
        }
    }

    FocusScope {
        id: overlayScope
        anchors.fill: parent
        enabled: controlPanel.isOpen && controlPanel.heldByUser

        onEnabledChanged: {
            if (enabled) {
                Qt.callLater(() => {
                    if (!overlayScope.enabled) return
                    // Password fields may have acquired focus since this callback
                    // was queued. Do not replace their focus with the background.
                    let focused = overlayScope.Window.window ? overlayScope.Window.window.activeFocusItem : null
                    while (focused) {
                        if (focused === drawerBg) return
                        focused = focused.parent
                    }
                    overlayScope.forceActiveFocus()
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
            enabled: overlayScope.enabled
            onActivated: controlPanel.isOpen = false
        }
    }

    Rectangle {
        id: drawerBg
        // Visual animation is independent of the ancestor hover/input region.
        parent: hoverBridge
        width: parent.width
        height: hoverBridge.targetDrawerHeight

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

            MusicWidget { preferVerticalScroll: panelScroll.contentHeight > panelScroll.availableHeight }
            Divider {}
            VolumeSlider {}
            BrightnessSlider {}
            Divider {}
            SystemResourceRow {}
            Divider {}
            WifiToggle { outputName: controlPanel.outputName }
            BluetoothToggle {}
        }
    }
}
