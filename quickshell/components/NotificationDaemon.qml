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
    property var surfaceScreen: null
    property int hoverCloseDelay: 300

    property int maxNotifications: 50

    signal newNotification(var data)
    signal dismissPopup()
    signal notificationRemoved(int id)

    property int _nextId: 1
    property var _closers: ({})
    property var _serverIds: ({})
    property var _serverObjects: ({})

    property Timer closeTimer: Timer {
        interval: root.hoverCloseDelay
        onTriggered: {
            root.isDrawerOpen = false
            root.surfaceScreen = null
        }
    }

    function beginHoverOpen() {
        closeTimer.stop()
        isDrawerOpen = true
    }

    function scheduleHoverClose() {
        closeTimer.restart()
    }

    function cancelHoverClose() {
        closeTimer.stop()
    }

    function toggleDrawer() {
        closeTimer.stop()
        isDrawerOpen = !isDrawerOpen
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
        root.notificationRemoved(id)
        delete root._closers[id]
        for (const serverId in root._serverIds) {
            if (root._serverIds[serverId] === id) {
                delete root._serverIds[serverId]
                delete root._serverObjects[serverId]
            }
        }
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

    function getIconSource(data) {
        if (!data) return ""
        if (data.image) {
            const img = data.image.toString()
            if (img.startsWith("file://") || img.startsWith("image://")) return img
            return img.startsWith("/") ? "file://" + img : img
        }
        if (data.appIcon) {
            const icon = data.appIcon.toString()
            if (icon.startsWith("file://") || icon.startsWith("image://")) return icon
            if (icon.startsWith("/")) return "file://" + icon
            return Quickshell.iconPath(icon, true)
        }
        return ""
    }

    property NotificationServer server: NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notif => {
            notif.tracked = true
            const serverId = notif.id
            const alreadyConnected = root._serverObjects[serverId] === notif
            const existingId = root._serverIds[notif.id]
            const id = existingId || root._nextId++
            const data = {
                summary: notif.summary || "",
                body: notif.body || "",
                appName: notif.appName || "App",
                time: new Date(),
                appIcon: notif.appIcon || "",
                image: notif.image || "",
                urgency: notif.urgency,
                expireTimeout: notif.expireTimeout,
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

            const row = {
                notifId: id,
                appName: data.appName,
                summary: data.summary,
                body: data.body.replace(/<img\b[^>]*>/gi, ""),
                timeText: Qt.formatTime(data.time, "hh:mm"),
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

            root.newNotification(Object.assign(data, { notifId: id }))

            if (alreadyConnected) return
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
    }

    property IpcHandler ipc: IpcHandler {
        target: "notifications"

        function closeLatest() {
            if (root.notificationModel.count > 0)
                root.closeNotification(0)
            root.dismissPopup()
        }
    }
}
