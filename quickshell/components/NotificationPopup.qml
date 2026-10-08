import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "."

PanelWindow {
    id: popup
    property int maxVisible: 3
    property int maxQueueLength: 20
    property int defaultDuration: 4000
    property int persistentDisplayDuration: 4000
    property int cardSpacing: 8
    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono
    property var _queue: []
    readonly property int queueCount: _queue.length
    readonly property int activeCount: active.count
    readonly property int closingCount: {
        let count = 0
        for (let i = 0; i < active.count; i++) if (active.get(i).closing) count++
        return count
    }
    property var store: ({})
    property int rev: 0
    signal updated(int id)
    ListModel { id: active }

    visible: active.count > 0
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
    implicitHeight: stack.implicitHeight

    function _max() { return Math.max(1, Math.min(3, maxVisible)) }
    function _durationFor(data) {
        // The installed Quickshell exposes milliseconds (tested over D-Bus).
        const requested = data ? Number(data.expireTimeout) : NaN
        if (data && data.urgency === NotificationUrgency.Critical) return 0
        if (isFinite(requested) && requested >= 0) return requested === 0 ? 0 : Math.max(1, Math.round(requested))
        return defaultDuration
    }
    function _activeIndex(id) {
        for (let i = 0; i < active.count; i++) if (active.get(i).notifId === id) return i
        return -1
    }
    function newestId() { return active.count ? active.get(0).notifId : -1 }
    function _put(data) { store[data.notifId] = data; rev++ }
    function _open(data) { _put(data); active.insert(0, {notifId: data.notifId, closing: false}) }
    function _fill() {
        while (_queue.length && active.count < _max()) {
            const next = _queue[0]
            _queue = _queue.slice(1)
            _open(next)
        }
    }
    function _remove(id, refill) {
        const index = _activeIndex(id)
        if (index >= 0) active.remove(index)
        delete store[id]
        if (refill !== false) _fill()
    }
    onMaxVisibleChanged: {
        while (active.count > _max()) _remove(active.get(active.count - 1).notifId, false)
        _fill()
    }
    function showNotification(data) {
        if (!data) return
        const id = data.notifId
        const index = _activeIndex(id)
        if (index >= 0) {
            _put(data)
            active.setProperty(index, "closing", false)
            updated(id)
            return
        }
        const queued = _queue.findIndex(d => d.notifId === id)
        if (data.urgency === NotificationUrgency.Critical) {
            _queue = _queue.filter(d => d.notifId !== id)
            while (active.count >= _max()) _remove(active.get(active.count - 1).notifId, false)
            _open(data)
        } else if (queued >= 0) {
            const next = _queue.slice(); next[queued] = data; _queue = next
        } else if (active.count < _max()) _open(data)
        else {
            const limit = Math.max(0, maxQueueLength)
            _queue = limit ? _queue.concat([data]).slice(-limit) : []
        }
    }
    // Hiding a popup never dismisses its server notification or history row.
    function _requestClose(id) {
        const index = _activeIndex(id)
        if (index >= 0 && !active.get(index).closing) active.setProperty(index, "closing", true)
    }
    function dismiss() {
        for (let i = 0; i < active.count; i++) {
            const row = active.get(i)
            if (!row.closing) { _requestClose(row.notifId); return }
        }
    }
    function dismissAll() { _queue = []; active.clear(); store = ({}); rev++ }
    function _forget(id) {
        _queue = _queue.filter(d => d.notifId !== id)
        _requestClose(id)
    }
    Connections {
        target: NotificationDaemon
        function onDoNotDisturbChanged() { if (NotificationDaemon.doNotDisturb) popup.dismissAll() }
        function onDismissPopup() { popup.dismiss() }
        function onNotificationRemoved(id) { popup._forget(id) }
    }
    Column {
        id: stack
        width: popup.width
        spacing: popup.cardSpacing
        move: Transition { NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic } }
        Repeater {
            model: active
            delegate: Item {
                id: slot
                required property int notifId
                required property int index
                readonly property var entry: { popup.rev; return popup.store[notifId] || null }
                readonly property int duration: entry ? popup._durationFor(entry) : 0
                property bool shown: false
                required property bool closing
                width: stack.width
                height: card.height
                Component.onCompleted: { shown = true; syncTimeout(true) }
                function beginClose() { popup._requestClose(notifId) }
                onClosingChanged: {
                    if (closing) { hideTimer.stop(); removeTimer.restart() }
                    else { removeTimer.stop(); syncTimeout(true) }
                }
                function syncTimeout(reset) {
                    if (closing || hover.hovered || (duration === 0 && popup.queueCount <= popup.closingCount)) hideTimer.stop()
                    else if (reset || !hideTimer.running) hideTimer.restart()
                }
                Timer { id: removeTimer; interval: 220; onTriggered: popup._remove(slot.notifId) }
                Timer {
                    id: hideTimer
                    interval: slot.duration > 0 ? slot.duration : popup.persistentDisplayDuration
                    onTriggered: {
                        // Closing cards already reserve slots for queued entries.
                        if (slot.duration > 0 || popup.queueCount > popup.closingCount) slot.beginClose()
                    }
                }
                Connections {
                    target: popup
                    function onUpdated(id) {
                        if (id !== slot.notifId) return
                        slot.syncTimeout(true)
                    }
                    function onClosingCountChanged() { if (slot.duration === 0) slot.syncTimeout(false) }
                    function onQueueCountChanged() { if (slot.duration === 0) slot.syncTimeout(false) }
                }
                Rectangle {
                    id: card
                    width: parent.width
                    implicitHeight: content.implicitHeight + 24
                    height: implicitHeight
                    radius: Theme.popupRadius
                    color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
                    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                    border.width: 1

                    x: slot.shown && !slot.closing ? 0 : 20
                    Behavior on x {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    opacity: slot.shown && !slot.closing ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    RowLayout {
                        id: content
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                        spacing: 12

                        Image {
                            source: NotificationDaemon.getIconSource(slot.entry)
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
                                    text: slot.entry ? (slot.entry.appName || "App") : "App"
                                    textFormat: Text.PlainText
                                    color: Colors.primary
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.family: popup.uiFont
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: slot.index === 0 && popup.queueCount > 0
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
                                    hint: "Hide popup (stays in panel)"
                                    onClicked: slot.beginClose()
                                }
                            }

                            Text {
                                text: slot.entry ? (slot.entry.summary || "") : ""
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
                                text: (slot.entry ? (slot.entry.body || "") : "").replace(/<img\b[^>]*>/gi, "")
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
                                notificationId: slot.entry ? slot.entry.notifId : -1
                                actions: slot.entry && slot.entry.actions ? slot.entry.actions : []
                            }

                        }
                    }
                    HoverHandler { id: hover; onHoveredChanged: slot.syncTimeout(true) }
                    TapHandler { onTapped: slot.beginClose() }
                }
            }
        }
    }
}
