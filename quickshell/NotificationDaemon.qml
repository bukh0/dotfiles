pragma Singleton
import QtQml
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var notifications: []
    property bool isDrawerOpen: false
    property int hoverCloseDelay: 300

    signal newNotification(var data)

    // Using a property for Timer since QtObject doesn't support default visual children
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
        // 1. Copy the current list so we can iterate safely
        let toClose = root.notifications.slice()
        
        // 2. Instantly empty the UI array to prevent sequential stuttering
        root.notifications = []
        
        // 3. Close them in the DBus backend
        toClose.forEach(n => {
            if (typeof n.close === "function") {
                try { n.close() } catch(e) {}
            }
        })
    }

    function closeNotification(idx) {
        let n = root.notifications[idx]
        if (n && typeof n.close === "function") {
            // Simply call close(). Do not manually edit the array here.
            // The `notif.closed` signal will fire automatically and handle the array cleanup.
            try { n.close() } catch(e) {}
        }
    }

    property NotificationServer server: NotificationServer {
        onNotification: notif => {
            let data = {
                summary: notif.summary || "",
                body: notif.body || "",
                appName: notif.appName || "App",
                time: new Date(),
                appIcon: notif.appIcon || "",
                image: notif.image || "",
                close: function() {
                    try { notif.close() } catch(e) {}
                }
            }

            // Insert new notification at the beginning of the list
            root.notifications = [data, ...root.notifications]
            root.newNotification(data)

            // SINGLE SOURCE OF TRUTH: 
            // Whether closed by the UI, by the system timeout, or by the app itself,
            // this signal always fires to cleanly remove it from the array.
            notif.closed.connect(() => {
                root.notifications = root.notifications.filter(n => n !== data)
            })
        }
    }
}
