import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "."

PanelWindow {
    id: root

    WlrLayershell.keyboardFocus: NotificationDaemon.drawerPinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool isOpen: NotificationDaemon.isDrawerOpen
    property int fadeOutDuration: 200
    property int drawerY: Theme.barTotalHeight + 4
    property int drawerRightMargin: 12
    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    visible: isOpen || drawerBg.opacity > 0
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Hover mode only intercepts the drawer. Pinning enables outside-click dismissal.
    mask: Region {
        readonly property bool full: NotificationDaemon.drawerPinned
        x: full ? 0 : drawerBg.x
        y: full ? 0 : drawerBg.y
        width: !root.isOpen ? 0 : full ? root.width : drawerBg.width
        height: !root.isOpen ? 0 : full ? root.height : drawerBg.height
    }

    property double now: Date.now()
    Timer { interval: 60000; running: root.isOpen; repeat: true; onTriggered: root.now = Date.now() }
    onIsOpenChanged: if (isOpen) { now = Date.now(); bgCloser.forceActiveFocus() }
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

    MouseArea {
        id: bgCloser
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        enabled: root.isOpen

        Keys.onEscapePressed: (event) => {
            NotificationDaemon.isDrawerOpen = false
            event.accepted = true
        }
        onClicked: (mouse) => {
            NotificationDaemon.isDrawerOpen = false
            NotificationDaemon.surfaceScreen = null
        }
    }

    Rectangle {
        id: drawerBg
        width: Math.min(Theme.notificationWidth, Math.max(0, root.width - root.drawerRightMargin * 2))
        height: Math.min(Theme.notificationHeight, Math.max(0, root.height - root.drawerY - 8),
                         2 * Theme.drawerPaddingH + drawerHeader.implicitHeight + Theme.drawerSpacing +
                         (NotificationDaemon.notificationModel.count ? notifList.contentHeight : 140))

        x: parent.width - width - root.drawerRightMargin
        y: root.isOpen ? root.drawerY : root.drawerY - 10

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
            onClicked: (mouse) => { mouse.accepted = true }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    NotificationDaemon.cancelHoverClose()
                    NotificationDaemon.isDrawerOpen = true
                } else {
                    NotificationDaemon.scheduleHoverClose()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.drawerPaddingH
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

                Button {
                    text: "DND"
                    checkable: true
                    checked: NotificationDaemon.doNotDisturb
                    onClicked: NotificationDaemon.doNotDisturb = checked
                    ToolTip.visible: hovered
                    ToolTip.text: "Do Not Disturb — keep notifications in history without popups"
                }
                Text {
                    text: "Clear All"
                    color: clearHover.hovered ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                    font.pixelSize: 12
                    font.family: root.uiFont
                    font.weight: Font.Medium

                    HoverHandler {
                        id: clearHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: NotificationDaemon.clearAll()
                    }
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

                rightMargin: ScrollBar.vertical.visible ? 8 : 0
                cacheBuffer: 300

                WheelHandler {
                    id: trackpadScroll
                    target: null
                    acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse | PointerDevice.TouchScreen

                    onWheel: function(wheelEvent) {
                        const pixelDelta = wheelEvent.pixelDelta.y
                        const angleDelta = wheelEvent.angleDelta.y
                        const delta = pixelDelta !== 0
                            ? pixelDelta
                            : angleDelta / 120 * 80
                        const minContentY = notifList.originY
                        const maxContentY = minContentY + Math.max(0, notifList.contentHeight - notifList.height)

                        notifList.contentY = Math.max(minContentY, Math.min(maxContentY, notifList.contentY - delta))
                        wheelEvent.accepted = true
                    }
                }

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 250 }
                    NumberAnimation { property: "x"; from: 30; to: 0; duration: 250; easing.type: Easing.OutCubic }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                    NumberAnimation { property: "scale"; to: 0.9; duration: 200 }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutQuad }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
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

                    width: ListView.view.width - ListView.view.rightMargin
                    implicitHeight: notifContent.implicitHeight + 24
                    radius: Theme.notificationItemRadius
                    color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    border.color: urgency === NotificationUrgency.Critical ? Colors.error : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
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
                                color: delegateRoot.urgency === NotificationUrgency.Critical
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

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 24
                                height: 24
                                radius: 12
                                color: closeHover.hovered ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.15) : "transparent"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: closeHover.hovered ? Colors.error : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                                    font.pixelSize: 14
                                    font.family: root.iconFont

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                HoverHandler {
                                    id: closeHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        NotificationDaemon.closeNotificationById(delegateRoot.notifId)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Layout.alignment: Qt.AlignTop

                            Image {
                                source: delegateRoot.iconSource
                                visible: source.toString() !== ""
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
                                    text: delegateRoot.body.replace(/<img\b[^>]*>/gi, "")
                                    textFormat: Text.StyledText
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                                    font.pixelSize: 12
                                    font.family: root.uiFont
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    visible: text !== ""
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
