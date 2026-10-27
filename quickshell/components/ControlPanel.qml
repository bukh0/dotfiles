import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: controlPanel
    Component.onDestruction: NetworkService.cancelPasswordPrompt(outputName)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: controlPanel.isOpen && controlPanel.heldByUser ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

    Connections {
        target: NotificationDaemon
        function onIsDrawerOpenChanged() {
            if (NotificationDaemon.isDrawerOpen) controlPanel.isOpen = false
        }
    }

    onIsOpenChanged: {
        if (isOpen) NotificationDaemon.isDrawerOpen = false
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
            Binding { target: panelScroll.contentItem; property: "pixelAligned"; value: false }

            WheelHandler {
                id: panelWheel
                target: null
                enabled: controlPanel.isOpen && panelScroll.contentHeight > panelScroll.availableHeight
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real destination: 0
                property real lastDelta: 0
                function bounded(y) {
                    const flick = panelScroll.contentItem
                    return Math.max(flick.originY, Math.min(flick.originY
                        + Math.max(0, flick.contentHeight - flick.height), y))
                }
                function scroll(event) {
                    // Own the gesture's zero-delta phase frames as well.
                    event.accepted = true
                    const ticks = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 15
                    if (ticks === 0) return
                    const flick = panelScroll.contentItem
                    flick.cancelFlick()
                    const delta = ticks * 180
                    const base = panelWheelAnimation.running && delta * lastDelta > 0 ? destination : flick.contentY
                    const maxLead = flick.height * 1.5
                    destination = bounded(Math.max(flick.contentY - maxLead,
                        Math.min(flick.contentY + maxLead, base - delta)))
                    lastDelta = delta
                    panelWheelAnimation.running = true
                }
                onWheel: event => scroll(event)
                onEnabledChanged: {
                    if (!enabled) {
                        panelWheelAnimation.running = false
                        const flick = panelScroll.contentItem
                        if (flick) {
                            flick.cancelFlick()
                            flick.contentY = bounded(flick.contentY)
                            destination = flick.contentY
                        }
                        lastDelta = 0
                    }
                }
            }
            FrameAnimation {
                id: panelWheelAnimation
                onTriggered: {
                    const flick = panelScroll.contentItem
                    panelWheel.destination = panelWheel.bounded(panelWheel.destination)
                    const remaining = panelWheel.destination - flick.contentY
                    if (Math.abs(remaining) < 0.5) {
                        flick.contentY = panelWheel.destination
                        running = false
                    } else flick.contentY = panelWheel.bounded(flick.contentY + remaining * (1 - Math.exp(-28 * frameTime)))
                }
            }
            Connections {
                target: panelScroll.contentItem
                function onMovementStarted() { panelWheelAnimation.running = false }
            }
            ScrollBar.vertical.onPressedChanged: if (ScrollBar.vertical.pressed) panelWheelAnimation.running = false

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
            VolumeSlider { preferVerticalScroll: panelScroll.contentHeight > panelScroll.availableHeight }
            BrightnessSlider { preferVerticalScroll: panelScroll.contentHeight > panelScroll.availableHeight }
            Divider {}
            SystemResourceRow {}
            Divider {}
            WifiToggle { outputName: controlPanel.outputName }
            BluetoothToggle {}
        }
    }
}
