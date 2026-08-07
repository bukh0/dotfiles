pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property var notifications: []
    property bool isDrawerOpen: false
    property int hoverCloseDelay: 300

    signal newNotification(var data)

    Timer {
        id: closeTimer
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
        root.notifications.forEach(n => {
            if (typeof n.close === "function") {
                try { n.close() } catch(e) {}
            }
        })
        root.notifications = []
    }

    function closeNotification(idx) {
        let n = root.notifications[idx]
        if (n && typeof n.close === "function") {
            try { n.close() } catch(e) {}
        }

        let arr = root.notifications.slice()
        arr.splice(idx, 1)
        root.notifications = arr
    }

    NotificationServer {
        id: server
        onNotification: notif => {
            let data = {
                summary: notif.summary || "",
                body: notif.body || "",
                appName: notif.appName || "App",
                time: new Date(),
                close: function() {
                    try { notif.close() } catch(e) {}
                }
            }

            // Insert new notification at the beginning
            root.notifications = [data, ...root.notifications]
            root.newNotification(data)

            notif.closed.connect(() => {
                root.notifications = root.notifications.filter(n => n !== data)
            })
        }
    }
}
