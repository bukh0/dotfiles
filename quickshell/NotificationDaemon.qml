pragma Singleton
import QtQml
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var notifications: []
    property bool isDrawerOpen: false
    property int hoverCloseDelay: 300

    signal newNotification(var data)

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
            // FIX: Instantly remove from the UI array to guarantee responsiveness
            const updated = root.notifications.slice()
            updated.splice(idx, 1)
            root.notifications = updated

            // Tell the system backend to close it
            if (typeof n.close === "function") {
                try { 
                    n.close() 
                } catch(e) {
                    console.warn("Failed to close notification at index", idx, ":", e)
                }
            }
        }
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

            root.notifications = [data, ...root.notifications]
            root.newNotification(data)

            notif.closed.connect(() => {
                if (root.notifications.includes(data)) {
                    root.notifications = root.notifications.filter(n => n !== data)
                }
            })
        }
    }
}
