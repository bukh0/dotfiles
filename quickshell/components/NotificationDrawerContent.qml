import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "."
import "NotificationBody.js" as NotificationBody

Rectangle {
    id: root
    signal linkActivated(string url)
    readonly property int criticalUrgency: 2 // freedesktop notification urgency

    property bool isOpen: NotificationDaemon.isDrawerOpen
    property int fadeOutDuration: 200
    property int barHeight: Theme.barTotalHeight
    property int drawerY: barHeight + 4
    property int drawerRightMargin: 12
    property int hoverEdgePadding: 18
    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    readonly property bool surfaceVisible: isOpen || drawerBg.opacity > 0
    // Hover mode intercepts only the drawer; pinning enables outside dismissal.
    readonly property rect inputRect: Qt.rect(
        NotificationDaemon.drawerPinned ? 0 : hoverBridge.x, barHeight,
        !isOpen ? 0 : NotificationDaemon.drawerPinned ? width : hoverBridge.width,
        !isOpen ? 0 : NotificationDaemon.drawerPinned ? Math.max(0, height - barHeight) : hoverBridge.height)
    visible: surfaceVisible
    // Retain the monitor until the closing animation is completely hidden.
    onVisibleChanged: if (!visible && !isOpen) NotificationDaemon.surfaceScreen = null
    color: "transparent"

    property double now: Date.now()
    Timer { interval: 60000; running: root.isOpen; repeat: true; onTriggered: root.now = Date.now() }
    onIsOpenChanged: if (isOpen) now = Date.now()
    function relativeTime(timestamp) {
        const minutes = Math.max(0, Math.floor((now - timestamp) / 60000))
        return minutes < 1 ? "now" : minutes < 60 ? minutes + "m" : minutes < 1440 ? Math.floor(minutes / 60) + "h" : Math.floor(minutes / 1440) + "d"
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.isOpen && NotificationDaemon.drawerPinned
        onActivated: NotificationDaemon.isDrawerOpen = false
    }
    Shortcut {
        sequence: "PgDown"
        enabled: root.isOpen && NotificationDaemon.drawerPinned
        onActivated: notifList.scrollTo(notifList.contentY + notifList.height * 0.9)
    }
    Shortcut {
        sequence: "PgUp"
        enabled: root.isOpen && NotificationDaemon.drawerPinned
        onActivated: notifList.scrollTo(notifList.contentY - notifList.height * 0.9)
    }
    Shortcut {
        sequence: "Home"
        enabled: root.isOpen && NotificationDaemon.drawerPinned
        onActivated: {
            notifList.scrollTo(notifList.originY)
            notifList.positionViewAtBeginning()
        }
    }
    Shortcut {
        sequence: "End"
        enabled: root.isOpen && NotificationDaemon.drawerPinned
        onActivated: {
            notifList.scrollToEnd()
        }
    }

    MouseArea {
        id: bgCloser
        anchors.fill: parent
        focus: enabled
        enabled: root.isOpen && NotificationDaemon.drawerPinned
        onEnabledChanged: if (enabled) forceActiveFocus()
        onClicked: (mouse) => {
            NotificationDaemon.isDrawerOpen = false
        }
    }

    // Own the controls and the gap below the bell, so crossing between them
    // cannot schedule a close while the pointer is still inside the panel.
    Item {
        id: hoverBridge
        x: Math.max(0, root.width - drawerBg.width - root.drawerRightMargin - root.hoverEdgePadding)
        y: root.barHeight
        width: Math.min(root.width - x, drawerBg.width + root.hoverEdgePadding * 2)
        // Only content/layout changes affect input height, never the visual slide.
        height: root.isOpen ? Math.max(0, root.drawerY - y + drawerBg.height) : 0
        HoverHandler {
            id: drawerHover
            enabled: root.isOpen
        }
    }
    Binding {
        target: NotificationDaemon
        property: "drawerHovered"
        value: root.isOpen && drawerHover.hovered
    }

    Rectangle {
        id: drawerBg
        parent: hoverBridge
        x: root.width - width - root.drawerRightMargin - hoverBridge.x
        width: Math.min(Theme.notificationWidth, Math.max(0, root.width - root.drawerRightMargin * 2))
        height: Math.min(Theme.notificationHeight, Math.max(0, root.height - root.drawerY - 8),
                         2 * Theme.drawerPaddingV + drawerHeader.implicitHeight + Theme.drawerSpacing +
                         (NotificationDaemon.notificationModel.count ? notifList.measuredHeight : 140))

        y: (root.isOpen ? root.drawerY : root.drawerY - 10) - hoverBridge.y

        Behavior on y {
            NumberAnimation { duration: root.fadeOutDuration; easing.type: Easing.OutCubic }
        }

        radius: Theme.notificationRadius
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: root.fadeOutDuration }
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Theme.drawerPaddingV
            anchors.bottomMargin: Theme.drawerPaddingV
            anchors.leftMargin: Theme.drawerPaddingH
            anchors.rightMargin: Theme.drawerPaddingH
            spacing: Theme.drawerSpacing

            RowLayout {
                id: drawerHeader
                Layout.fillWidth: true

                Text {
                    text: "Notifications"
                    color: Colors.primary
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.family: root.uiFont
                    Layout.fillWidth: true
                }

                NotificationButton {
                    text: "DND"
                    glyph: NotificationDaemon.doNotDisturb ? "󰂛" : "󰂚"
                    checked: NotificationDaemon.doNotDisturb
                    onClicked: NotificationDaemon.toggleDnd()
                    hint: checked ? "Do Not Disturb is on" : "Turn on Do Not Disturb"
                }
                NotificationButton {
                    text: "Clear"
                    quiet: true
                    enabled: NotificationDaemon.notificationModel.count > 0
                    hint: "Clear all notifications"
                    onClicked: NotificationDaemon.clearAll()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationDaemon.notificationModel.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂜"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.2)
                        font.pixelSize: 42
                        font.family: root.iconFont
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No new notifications"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                        font.pixelSize: 13
                        font.family: root.uiFont
                    }
                }
            }

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationDaemon.notificationModel.count > 0
                clip: true
                spacing: 10
                model: NotificationDaemon.notificationModel
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 2500
                maximumFlickVelocity: 2500

                rightMargin: 8
                cacheBuffer: 300

                // Retain exact measurements when delegates leave the cache.
                // Unknown rows reserve the maximum height; once all rows are
                // measured, short lists can fit without relying on estimates.
                property var rowHeights: ({})
                readonly property real measuredHeight: {
                    let total = Math.max(0, count - 1) * spacing
                    for (let i = 0; i < count; i++) {
                        const h = rowHeights[String(model.get(i).notifId)]
                        if (h === undefined) return Theme.notificationHeight
                        total += h
                    }
                    return total
                }
                function measureRow(id, height) {
                    if (id === undefined || height <= 0 || rowHeights[String(id)] === height) return
                    const next = Object.assign({}, rowHeights)
                    next[String(id)] = height
                    rowHeights = next
                }
                function refreshMeasurements(reset) {
                    const next = {}
                    for (let i = 0; i < count; i++) {
                        const id = String(model.get(i).notifId)
                        const card = itemAtIndex(i)
                        if (card) next[id] = card.implicitHeight
                        else if (!reset && rowHeights[id] !== undefined) next[id] = rowHeights[id]
                    }
                    rowHeights = next
                }
                onCountChanged: Qt.callLater(() => refreshMeasurements(false))
                onWidthChanged: Qt.callLater(() => refreshMeasurements(true))

                function scrollToEnd() {
                    scrollTo(contentY)
                    positionViewAtEnd()
                    // The first jump creates variable-height tail delegates.
                    // Align again once their real sizes have reached the layout.
                    Qt.callLater(function() {
                        notifList.forceLayout()
                        notifList.positionViewAtEnd()
                        const last = notifList.itemAtIndex(notifList.count - 1)
                        if (last) notifList.contentY = Math.max(notifList.originY, last.y + last.height - notifList.height)
                    })
                }

                function scrollTo(y) {
                    wheelAnimation.running = false
                    cancelFlick()
                    contentY = trackpadScroll.bounded(y)
                }

                // Animate discrete wheel steps; preserve native touchpad momentum.
                onDraggingChanged: if (dragging) wheelAnimation.running = false
                onVisibleChanged: if (!visible) wheelAnimation.running = false

                WheelHandler {
                    id: trackpadScroll
                    target: null
                    acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
                    property real destination: 0
                    property real lastDelta: 0

                    function bounded(y) {
                        const minimum = notifList.originY
                        const maximum = minimum + Math.max(0, notifList.contentHeight - notifList.height)
                        return Math.max(minimum, Math.min(maximum, y))
                    }

                    function scroll(pixelDelta, angleDelta) {
                        if (pixelDelta === 0 && angleDelta === 0) return false
                        notifList.cancelFlick()
                        if (pixelDelta !== 0) {
                            wheelAnimation.running = false
                            notifList.contentY = bounded(notifList.contentY - pixelDelta)
                            destination = notifList.contentY
                        } else {
                            const delta = angleDelta / 120 * 100
                            // Reversing direction responds immediately instead of
                            // first consuming the previous direction's queued travel.
                            const base = wheelAnimation.running && delta * lastDelta > 0
                                ? destination : notifList.contentY
                            destination = bounded(base - delta)
                            lastDelta = delta
                            wheelAnimation.running = true
                        }
                        return true
                    }

                    onWheel: event => {
                        event.accepted = scroll(event.pixelDelta.y, event.angleDelta.y)
                    }
                }

                FrameAnimation {
                    id: wheelAnimation
                    onTriggered: {
                        trackpadScroll.destination = trackpadScroll.bounded(trackpadScroll.destination)
                        const remaining = trackpadScroll.destination - notifList.contentY
                        if (Math.abs(remaining) < 0.5) {
                            notifList.contentY = trackpadScroll.destination
                            running = false
                        } else {
                            notifList.contentY = trackpadScroll.bounded(notifList.contentY
                                + remaining * (1 - Math.exp(-28 * frameTime)))
                        }
                    }
                }

                // Keep insertion and displacement synchronous: text and actions
                // can resize cards mid-transition and leave stale list positions.
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                    NumberAnimation { property: "scale"; to: 0.9; duration: 200 }
                }

                ScrollBar.vertical: ScrollBar {
                    onPressedChanged: if (pressed) wheelAnimation.running = false
                    policy: ScrollBar.AsNeeded
                    // A custom contentItem does not inherit the style's
                    // hide-when-full opacity binding.
                    visible: notifList.contentHeight > notifList.height + 0.5
                    interactive: true
                    width: 6
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.3)
                    }
                }

                delegate: Rectangle {
                    id: delegateRoot
                    required property int notifId
                    required property string appName
                    required property string summary
                    required property string body
                    required property string timeText
                    required property double timestamp
                    required property int urgency
                    required property string iconSource
                    property bool bodyExpanded: false
                    onBodyChanged: bodyExpanded = false

                    width: ListView.view.width - ListView.view.rightMargin
                    implicitHeight: notifContent.implicitHeight + 24
                    onImplicitHeightChanged: notifList.measureRow(notifId, implicitHeight)
                    Component.onCompleted: notifList.measureRow(notifId, implicitHeight)
                    radius: Theme.notificationItemRadius
                    color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    border.color: urgency === root.criticalUrgency ? Colors.error : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                    border.width: 1

                    ColumnLayout {
                        id: notifContent
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 12
                        }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: delegateRoot.appName
                                textFormat: Text.PlainText
                                color: delegateRoot.urgency === root.criticalUrgency
                                    ? Colors.error : Colors.primary
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.family: root.uiFont
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.relativeTime(delegateRoot.timestamp)
                                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                                font.pixelSize: 10
                                font.family: root.uiFont
                                Layout.rightMargin: 8
                            }

                            NotificationButton {
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 28
                                implicitWidth: 28
                                glyph: "󰅖"
                                quiet: true
                                hint: "Dismiss notification"
                                onClicked: NotificationDaemon.closeNotificationById(delegateRoot.notifId)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Layout.alignment: Qt.AlignTop

                            Image {
                                source: delegateRoot.iconSource
                                visible: source.toString() !== "" && status !== Image.Error
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                Layout.alignment: Qt.AlignTop
                                fillMode: Image.PreserveAspectFit
                                clip: true
                                asynchronous: true
                                sourceSize: Qt.size(96, 96)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Layout.alignment: Qt.AlignTop

                                Text {
                                    text: delegateRoot.summary
                                    textFormat: Text.PlainText
                                    color: Colors.surfaceFg
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    font.family: root.uiFont
                                    wrapMode: Text.Wrap
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }

                                Text {
                                    id: bodyText
                                    // Preserve formatting and explicit links without loading remote images.
                                    text: NotificationBody.styled(delegateRoot.body)
                                    textFormat: Text.StyledText
                                    linkColor: Colors.primary
                                    onLinkActivated: link => { if (NotificationBody.safeLink(link)) root.linkActivated(link) }
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                                    font.pixelSize: 12
                                    font.family: root.uiFont
                                    wrapMode: Text.Wrap
                                    maximumLineCount: delegateRoot.bodyExpanded ? 2147483647 : 4
                                    elide: delegateRoot.bodyExpanded ? Text.ElideNone : Text.ElideRight
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                                NotificationButton {
                                    visible: bodyText.truncated || delegateRoot.bodyExpanded
                                    text: delegateRoot.bodyExpanded ? "Show less" : "Show more"
                                    glyph: delegateRoot.bodyExpanded ? "▴" : "▾"
                                    quiet: true
                                    hint: delegateRoot.bodyExpanded ? "Collapse message" : "Read full message"
                                    onClicked: delegateRoot.bodyExpanded = !delegateRoot.bodyExpanded
                                }
                            }
                        }
                        NotificationActions { notificationId: delegateRoot.notifId }

                    }
                }
            }
        }
    }
}
