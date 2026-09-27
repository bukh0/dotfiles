pragma Singleton
import QtQml
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    // Source of truth for the drawer. Roles per row: notifId, appName,
    // summary, body, timeText, iconSource. Always mutate via
    // insert/remove/setProperty — never reassign a whole new model — or
    // you're back to the "everything replays its transition" problem
    // this was fixed for.
    property ListModel notificationModel: ListModel {}

    property bool isDrawerOpen: false
    property var surfaceScreen: null
    property int hoverCloseDelay: 300

    // Hard cap on retained notifications. Nothing expires on its own —
    // once past this depth, oldest entries get evicted and their
    // underlying Notification objects closed (releasing icon pixmaps
    // etc.) so memory stays bounded even if you never touch "Clear All".
    property int maxNotifications: 100

    signal newNotification(var data)
    signal dismissPopup()

    property int _nextId: 1
    property var _closers: ({})   // notifId -> close() function

    property Timer closeTimer: Timer {
        interval: root.hoverCloseDelay
        onTriggered: root.isDrawerOpen = false
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
            try { fn() } catch(e) { console.warn(e) }
        }
        delete root._closers[id]
    }

    function clearAll() {
        while (root.notificationModel.count > 0) {
            const lastIndex = root.notificationModel.count - 1
            const id = root.notificationModel.get(lastIndex).notifId
            root.notificationModel.remove(lastIndex)
            root._closeById(id)
        }
    }

    function closeNotification(idx) {
        if (idx < 0 || idx >= root.notificationModel.count) return
        const id = root.notificationModel.get(idx).notifId
        root.notificationModel.remove(idx)
        root._closeById(id)
    }

    function getIconSource(data) {
        if (!data) return ""
        if (data.image) {
            const img = data.image.toString()
            return img.startsWith("/") ? "file://" + img : img
        }
        if (data.appIcon) {
            const icon = data.appIcon.toString()
            if (icon.startsWith("/")) return "file://" + icon
            return Quickshell.iconPath(icon)
        }
        return ""
    }

    property NotificationServer server: NotificationServer {
        onNotification: notif => {
            const id = root._nextId++
            const data = {
                summary: notif.summary || "",
                body: notif.body || "",
                appName: notif.appName || "App",
                time: new Date(),
                appIcon: notif.appIcon || "",
                image: notif.image || "",
                close: () => {
                    try { notif.close() } catch(e) {}
                }
            }

            root._closers[id] = data.close

            root.notificationModel.insert(0, {
                notifId: id,
                appName: data.appName,
                summary: data.summary,
                body: data.body,
                timeText: Qt.formatTime(data.time, "hh:mm"),
                iconSource: root.getIconSource(data)
            })

            // Evict oldest past the cap. Newest is always at index 0, so
            // oldest is always at the tail.
            while (root.notificationModel.count > root.maxNotifications) {
                const lastIdx = root.notificationModel.count - 1
                const overflowId = root.notificationModel.get(lastIdx).notifId
                root.notificationModel.remove(lastIdx)
                root._closeById(overflowId)
            }

            root.newNotification(data)

            notif.closed.connect(() => {
                for (let i = 0; i < root.notificationModel.count; i++) {
                    if (root.notificationModel.get(i).notifId === id) {
                        root.notificationModel.remove(i)
                        break
                    }
                }
                delete root._closers[id]
            })
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "notifications"

        function closeLatest(): void {
            root.dismissPopup()
        }
    }
}
