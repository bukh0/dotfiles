pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var notifications: []
    property bool isDrawerOpen: false
    property int hoverCloseDelay: 300

    // Hard cap on retained notifications. Nothing expires on its own —
    // once you're past this depth, the OLDEST entries get evicted and
    // their underlying Notification objects closed (releasing icon
    // pixmaps etc.) so memory stays bounded even if you never touch
    // "Clear All".
    property int maxNotifications: 100

    signal newNotification(var data)
    signal dismissPopup()

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

    function clearAll() {
        const toClose = root.notifications.slice()
        root.notifications = []

        toClose.forEach(n => {
            if (typeof n.close === "function") {
                try { n.close() } catch(e) { console.warn(e) }
            }
        })
    }

    function closeNotification(idx) {
        const n = root.notifications[idx]
        if (n) {
            const updated = root.notifications.slice()
            updated.splice(idx, 1)
            root.notifications = updated

            if (typeof n.close === "function") {
                try {
                    n.close()
                } catch(e) {
                    console.warn("Failed to close notification at index", idx, ":", e)
                }
            }
        }
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

            let updated = [data, ...root.notifications]

            // Memory Management: Evict oldest past the cap and actually close them
            // so the underlying Quickshell Notification gets released.
            if (updated.length > root.maxNotifications) {
                const overflow = updated.slice(root.maxNotifications)
                updated = updated.slice(0, root.maxNotifications)
                overflow.forEach(n => {
                    if (typeof n.close === "function") {
                        try { n.close() } catch(e) {}
                    }
                })
            }

            root.notifications = updated
            root.newNotification(data)

            notif.closed.connect(() => {
                if (root.notifications.includes(data)) {
                    root.notifications = root.notifications.filter(n => n !== data)
                }
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
