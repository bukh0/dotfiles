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

    // Called from NotificationBell when the cursor enters the bell icon.
    function beginHoverOpen() {
        closeTimer.stop()
        isDrawerOpen = true
    }

    // Called when the cursor leaves the bell, or leaves the drawer itself.
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
        for (let i = root.notifications.length - 1; i >= 0; i--) {
            let n = root.notifications[i]
            if (n && typeof n.close === "function") {
                try {
                    n.close()
                } catch (e) {}
            }
        }
        root.notifications = []
    }

    function closeNotification(idx) {
        let n = root.notifications[idx]

        if (n && typeof n.close === "function") {
            try {
                n.close()
            } catch(e) {}
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
                appName: notif.appName || "",
                close: function() {
                    try {
                        notif.close()
                    } catch(e) {}
                }
            }

            root.notifications = [data].concat(root.notifications)
            root.newNotification(data)

            notif.closed.connect(() => {
                root.notifications = root.notifications.filter(n => n !== data)
            })
        }
    }
}
