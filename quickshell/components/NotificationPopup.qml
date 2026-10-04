import QtQuick
import QtQuick.Controls
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
    // Persistent notifications stay in history, but must not monopolize the
    // one popup slot when other notifications are waiting.
    property int persistentDisplayDuration: 4000

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

    Timer {
        id: yieldTimer
        interval: popup.persistentDisplayDuration
        onTriggered: popup._advanceQueue()
    }

    on_QueueChanged: _scheduleYield()

    function _scheduleYield() {
        if (!popup.isVisible || popup.displayDuration !== 0 || popup._queue.length === 0 || popupHover.hovered)
            yieldTimer.stop()
        else if (!yieldTimer.running)
            yieldTimer.start()
    }

    onIsVisibleChanged: {
        if (!isVisible && popup._queue.length > 0) advanceTimer.restart()
    }

    Connections {
        target: NotificationDaemon
        function onDoNotDisturbChanged() { if (NotificationDaemon.doNotDisturb) popup.dismissAll() }
        function onDismissPopup() {
            popup.dismiss()
        }
        function onNotificationRemoved(id) {
            popup._queue = popup._queue.filter(data => data.notifId !== id)
            if (popup.notificationData && popup.notificationData.notifId === id)
                popup.dismiss()
        }
    }

    // The installed Quickshell exposes milliseconds (verified over private D-Bus).
    function _durationFor(data) {
        const requested = data ? Number(data.expireTimeout) : NaN
        if (data && data.urgency === NotificationUrgency.Critical) return 0
        if (isFinite(requested) && requested >= 0) return requested === 0 ? 0 : Math.max(1, Math.round(requested))
        return 4000
    }

    function restartTimeout() {
        hideTimer.stop()
        if (popup.isVisible && !popupHover.hovered && popup.displayDuration > 0) hideTimer.start()
    }

    function _advanceQueue() {
        if (popup._queue.length === 0) return
        const next = popup._queue[0]
        popup._queue = popup._queue.slice(1)
        popup._show(next)
    }

    function _show(data) {
        advanceTimer.stop()
        yieldTimer.stop()
        popup.displayDuration = _durationFor(data)
        popup.notificationData = data
        popup.isVisible = true
        restartTimeout()
        _scheduleYield()
    }

    function showNotification(data) {
        if (popup.notificationData && popup.notificationData.notifId === data.notifId && popup.isVisible) {
            popup.notificationData = data
            popup.displayDuration = _durationFor(data)
            restartTimeout()
            _scheduleYield()
            return
        }
        // Urgent alerts interrupt immediately, including queued replacements
        // promoted to critical. The previous alert remains in the drawer.
        if (data.urgency === NotificationUrgency.Critical) {
            popup._queue = popup._queue.filter(item => item.notifId !== data.notifId)
            popup._show(data)
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
        popup._show(data)
    }

    function dismiss() {
        hideTimer.stop()
        yieldTimer.stop()
        popup.isVisible = false
    }

    function dismissAll() {
        advanceTimer.stop()
        yieldTimer.stop()
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

                    NotificationButton {
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 28
                        implicitWidth: 28
                        glyph: "󰅖"
                        quiet: true
                        hint: "Dismiss popup"
                        onClicked: popup.dismiss()
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
                NotificationActions {
                    notificationId: popup.notificationData ? popup.notificationData.notifId : -1
                    actions: popup.notificationData && popup.notificationData.actions ? popup.notificationData.actions : []
                }

            }
        }

        HoverHandler {
            id: popupHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop()
                    yieldTimer.stop()
                } else if (popup.isVisible) {
                    popup.restartTimeout()
                    popup._scheduleYield()
                }
            }
        }

        TapHandler { onTapped: popup.dismiss() }
    }
}
