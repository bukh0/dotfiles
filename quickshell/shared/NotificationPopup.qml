import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "."

PanelWindow {
    id: popup

    property var notificationData: null
    property int displayDuration: 4000
    property bool isVisible: false

    property var _queue: []
    property int maxQueueLength: 20

    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    visible: isVisible || bg.opacity > 0
    color: "transparent"

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barTotalHeight + 1
        right: 10
    }

    implicitWidth: Theme.popupWidth
    implicitHeight: bg.implicitHeight

    Timer {
        id: hideTimer
        interval: popup.displayDuration
        onTriggered: popup.isVisible = false
        repeat: false
    }

    Timer {
        id: advanceTimer
        interval: 220
        onTriggered: popup._advanceQueue()
    }

    onIsVisibleChanged: {
        if (!isVisible && popup._queue.length > 0) advanceTimer.restart()
    }

    Connections {
        target: NotificationDaemon
        function onDismissPopup() {
            popup.dismiss()
        }
        function onNotificationRemoved(id) {
            popup._queue = popup._queue.filter(data => data.notifId !== id)
            if (popup.notificationData && popup.notificationData.notifId === id)
                popup.dismiss()
        }
    }

    function _durationFor(data) {
        const requested = data ? Number(data.expireTimeout) : 0
        if (data && data.urgency === NotificationUrgency.Critical) return 0
        if (requested >= 0) return requested
        return 4000
    }

    function restartTimeout() {
        hideTimer.stop()
        if (popup.displayDuration > 0) hideTimer.start()
    }

    function _advanceQueue() {
        if (popup._queue.length === 0) return
        const next = popup._queue[0]
        popup._queue = popup._queue.slice(1)
        popup.displayDuration = _durationFor(next)
        popup.notificationData = next
        popup.isVisible = true
        restartTimeout()
    }

    function showNotification(data) {
        if (popup.notificationData && popup.notificationData.notifId === data.notifId && popup.isVisible) {
            popup.notificationData = data
            popup.displayDuration = _durationFor(data)
            restartTimeout()
            return
        }
        const queuedIndex = popup._queue.findIndex(item => item.notifId === data.notifId)
        if (queuedIndex >= 0) {
            const updated = popup._queue.slice()
            updated[queuedIndex] = data
            popup._queue = updated
            return
        }
        if (popup.isVisible || advanceTimer.running) {
            popup._queue = popup._queue.concat([data]).slice(-popup.maxQueueLength)
            return
        }
        popup.displayDuration = _durationFor(data)
        popup.notificationData = data
        popup.isVisible = true
        restartTimeout()
    }

    function dismiss() {
        hideTimer.stop()
        popup.isVisible = false
    }

    function dismissAll() {
        advanceTimer.stop()
        popup._queue = []
        popup.isVisible = false
        hideTimer.stop()
    }

    Rectangle {
        id: bg
        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: Theme.popupRadius
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        x: popup.isVisible ? 0 : 20
        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        opacity: popup.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        RowLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 12

            Image {
                source: NotificationDaemon.getIconSource(popup.notificationData)
                visible: source.toString() !== ""
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignTop
                fillMode: Image.PreserveAspectFit
                clip: true
                asynchronous: true
                sourceSize: Qt.size(84, 84)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: popup.notificationData ? (popup.notificationData.appName || "App") : "App"
                        textFormat: Text.PlainText
                        color: Colors.primary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.family: popup.uiFont
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: popup._queue.length > 0
                        text: "+" + popup._queue.length
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: popup.uiFont
                    }

                    Rectangle {
                        id: dismissButton
                        z: 1
                        Layout.alignment: Qt.AlignVCenter
                        width: 24
                        height: 24
                        radius: 12
                        color: dismissHover.hovered ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.15) : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: dismissHover.hovered ? Colors.error : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                            font.pixelSize: 14
                            font.family: popup.iconFont

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        HoverHandler {
                            id: dismissHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: popup.dismiss()
                        }
                    }
                }

                Text {
                    text: popup.notificationData ? (popup.notificationData.summary || "") : ""
                    textFormat: Text.PlainText
                    color: Colors.surfaceFg
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: popup.uiFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: text !== ""
                }

                Text {
                    text: (popup.notificationData ? (popup.notificationData.body || "") : "").replace(/<img\b[^>]*>/gi, "")
                    textFormat: Text.StyledText
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                    font.pixelSize: 12
                    font.family: popup.uiFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: text !== ""
                }
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) hideTimer.stop()
                else if (popup.isVisible) popup.restartTimeout()
            }
        }

        TapHandler { onTapped: popup.dismiss() }
    }
}
