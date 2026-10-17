pragma Singleton
import QtQml
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    property ListModel notificationModel: ListModel {}

    property bool isDrawerOpen: false
    property bool drawerPinned: false
    property bool doNotDisturb: false
    property bool _dndReady: false
    Component.onCompleted: {
        doNotDisturb = _dndStore.text().trim() === "1"
        _dndReady = true
    }
    property int actionRevision: 0
    onIsDrawerOpenChanged: if (!isDrawerOpen) drawerPinned = false
    onDoNotDisturbChanged: {
        if (_dndReady) _dndStore.setText(doNotDisturb ? "1\n" : "0\n")
        if (doNotDisturb) root.dismissPopup()
    }
    property var surfaceScreen: null
    property int hoverCloseDelay: 510
    property var hoveredTrigger: null
    property bool drawerHovered: false
    onDrawerHoveredChanged: {
        if (drawerHovered) cancelHoverClose()
        else scheduleHoverClose()
    }

    property FileView _dndStore: FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell_dnd"
        preload: false
        blockLoading: true
        printErrors: false
    }

    property int maxNotifications: 50

    signal newNotification(var data)
    signal dismissPopup()
    signal dismissPopupById(int id)
    signal notificationRemoved(int id)

    // The shell's PersistentProperties keeps this small primitive map across
    // reloads. Reloadable children inside a QML singleton are not restored.
    property var timestamps: ({})
    function restoreTimestamps(json) {
        const restored = ({})
        try {
            const parsed = JSON.parse(json)
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                for (const id of Object.keys(parsed)) {
                    const value = parsed[id]
                    if (typeof value === "number" && isFinite(value) && value >= 0
                            && value <= 8640000000000000)
                        restored[id] = value
                }
            }
        } catch (_) {}
        timestamps = restored
    }

    property int _nextId: 1
    property var _closers: ({})
    property var _serverIds: ({})
    property var _serverObjects: ({})

    property Timer closeTimer: Timer {
        interval: root.hoverCloseDelay
        onTriggered: {
            if (!root.drawerPinned && !root.hoveredTrigger && !root.drawerHovered)
                root.isDrawerOpen = false
        }
    }

    function beginHoverOpen() {
        closeTimer.stop()
        isDrawerOpen = true
    }

    function scheduleHoverClose() {
        if (isDrawerOpen && !drawerPinned && !hoveredTrigger && !drawerHovered) closeTimer.restart()
    }

    function setTriggerHovered(trigger, hovered) {
        if (hovered) {
            hoveredTrigger = trigger
            cancelHoverClose()
        } else if (hoveredTrigger === trigger) {
            hoveredTrigger = null
            scheduleHoverClose()
        }
    }

    function cancelHoverClose() {
        closeTimer.stop()
    }

    function toggleDrawer() {
        closeTimer.stop()
        if (isDrawerOpen && drawerPinned) isDrawerOpen = false
        else { drawerPinned = true; isDrawerOpen = true }
    }

    function toggleDnd() {
        doNotDisturb = !doNotDisturb
    }

    function setDnd(enabled) {
        doNotDisturb = !!enabled
    }

    function _closeById(id) {
        const fn = root._closers[id]
        if (typeof fn === "function") {
            try {
                fn()
            } catch(e) {
                console.warn("notifications: failed to close", id, e)
            }
        }
        delete root._closers[id]
    }

    function _forgetLocalId(id) {
        if (!Object.values(root._serverIds).includes(id)) return
        delete root._closers[id]
        for (const serverId in root._serverIds) {
            if (root._serverIds[serverId] === id) {
                const times = Object.assign({}, root.timestamps)
                delete times[serverId]
                root.timestamps = times
                delete root._serverIds[serverId]
                delete root._serverObjects[serverId]
            }
        }
        // Bindings and signal handlers run synchronously; expose the completed
        // removal before letting them inspect actions or dismiss another row.
        root.actionRevision++
        root.notificationRemoved(id)
    }

    function clearAll() {
        while (root.notificationModel.count > 0) {
            const lastIndex = root.notificationModel.count - 1
            const id = root.notificationModel.get(lastIndex).notifId
            root.notificationModel.remove(lastIndex)
            root._closeById(id)
            root._forgetLocalId(id)
        }
    }

    function closeNotification(idx) {
        if (idx < 0 || idx >= root.notificationModel.count) return
        const id = root.notificationModel.get(idx).notifId
        closeNotificationById(id)
    }

    function closeNotificationById(id) {
        for (let i = 0; i < root.notificationModel.count; i++) {
            if (root.notificationModel.get(i).notifId !== id) continue
            root.notificationModel.remove(i)
            root._closeById(id)
            root._forgetLocalId(id)
            return
        }
    }

    function _actionData(notif) {
        return Array.from(notif.actions).map((action, index) => {
            const identifier = action.identifier || ""
            const label = (action.text || "").trim()
            return {
                identifier: identifier,
                text: label || (identifier === "default" ? "Open" : "Action " + (index + 1))
            }
        })
    }

    function actionsFor(id) {
        const revision = root.actionRevision
        for (const serverId in root._serverIds) {
            if (root._serverIds[serverId] === id) {
                const notif = root._serverObjects[serverId]
                return notif ? root._actionData(notif) : []
            }
        }
        return []
    }

    function invokeAction(id, index) {
        for (const serverId in root._serverIds) {
            if (root._serverIds[serverId] !== id) continue
            const notif = root._serverObjects[serverId]
            if (notif && index >= 0 && index < notif.actions.length) notif.actions[index].invoke()
            return
        }
    }

    function localFileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    function getIconSource(data) {
        if (!data) return ""
        if (data.image) {
            const img = data.image.toString()
            if (img.startsWith("file://") || img.startsWith("image://")) return img
            return img.startsWith("/") ? localFileUrl(img) : img
        }
        if (data.appIcon) {
            const icon = data.appIcon.toString()
            if (icon.startsWith("file://") || icon.startsWith("image://")) return icon
            if (icon.startsWith("/")) return localFileUrl(icon)
            return Quickshell.iconPath(icon, true)
        }
        return ""
    }

    function _receiveNotification(notif) {
        notif.tracked = true
        const serverId = notif.id
        const alreadyConnected = root._serverObjects[serverId] === notif
        // lastGeneration remains true on subsequent app replacements too.
        // Only the first delivery of this object is restoration.
        const restoring = notif.lastGeneration && !alreadyConnected
        const savedTime = root.timestamps[serverId]
        const timestamp = restoring && typeof savedTime === "number" ? savedTime : Date.now()
        root.timestamps = Object.assign({}, root.timestamps, {[serverId]: timestamp})
        const existingId = root._serverIds[notif.id]
        const id = existingId || root._nextId++
        const data = {
            summary: notif.summary || "",
            body: notif.body || "",
            appName: notif.appName || "App",
            time: new Date(timestamp),
            appIcon: notif.appIcon || "",
            image: notif.image || "",
            urgency: Number(notif.urgency),
            expireTimeout: notif.expireTimeout,
            actions: root._actionData(notif),
            close: () => {
                try {
                    // Notification has no close(); dismiss() is the
                    // user-dismissed close that emits `closed`.
                    notif.dismiss()
                } catch(e) {
                    console.warn("notifications: failed to close server notification", notif.id, e)
                }
            }
        }

        root._closers[id] = data.close
        root._serverIds[notif.id] = id
        root._serverObjects[notif.id] = notif
        root.actionRevision++

        const row = {
            notifId: id,
            appName: data.appName,
            summary: data.summary,
            body: data.body.replace(/<img\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/gi, ""),
            timeText: Qt.formatTime(data.time, "hh:mm"),
            timestamp: data.time.getTime(),
            urgency: data.urgency,
            iconSource: root.getIconSource(data)
        }
        if (existingId) {
            let replaced = false
            for (let i = 0; i < root.notificationModel.count; i++) {
                if (root.notificationModel.get(i).notifId === id) {
                    root.notificationModel.set(i, row)
                    replaced = true
                    break
                }
            }
            if (!replaced) root.notificationModel.insert(0, row)
        } else {
            root.notificationModel.insert(0, row)
        }

        while (root.notificationModel.count > root.maxNotifications) {
            const lastIdx = root.notificationModel.count - 1
            const overflowId = root.notificationModel.get(lastIdx).notifId
            root.notificationModel.remove(lastIdx)
            root._closeById(overflowId)
            root._forgetLocalId(overflowId)
        }

        if (!restoring && (!root.doNotDisturb || data.urgency === NotificationUrgency.Critical))
            root.newNotification(Object.assign(data, { notifId: id }))
        else if (!restoring && existingId)
            root.dismissPopupById(id)

        if (alreadyConnected) return
        // Replacements mutate the existing Notification; the server does not
        // re-emit onNotification. Coalesce the resulting property signals once.
        let updateQueued = false
        const update = () => {
            if (updateQueued) return
            updateQueued = true
            Qt.callLater(() => {
                updateQueued = false
                if (root._serverObjects[serverId] === notif) root._receiveNotification(notif)
            })
        }
        notif.summaryChanged.connect(update)
        notif.bodyChanged.connect(update)
        notif.appNameChanged.connect(update)
        notif.appIconChanged.connect(update)
        notif.imageChanged.connect(update)
        notif.urgencyChanged.connect(update)
        notif.expireTimeoutChanged.connect(update)
        notif.actionsChanged.connect(update)
        notif.closed.connect(() => {
            if (root._serverObjects[serverId] !== notif) return
            for (let i = 0; i < root.notificationModel.count; i++) {
                if (root.notificationModel.get(i).notifId === id) {
                    root.notificationModel.remove(i)
                    break
                }
            }
            root._forgetLocalId(id)
        })
    }

    property NotificationServer server: NotificationServer {
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notif => root._receiveNotification(notif)
    }


    property IpcHandler ipc: IpcHandler {
        target: "notifications"

        function closeLatest(): void {
            root.dismissPopup()
        }

        function toggleDnd(): void {
            root.toggleDnd()
        }

        function setDnd(enabled: bool): void {
            root.setDnd(enabled)
        }
    }
}
