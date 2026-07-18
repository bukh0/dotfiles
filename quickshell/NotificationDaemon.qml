pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property var notifications: []
    property bool isDrawerOpen: false

    signal newNotification(var data)

    function toggleDrawer() {
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
        
        // 1. Tell the system we dismissed it
        if (n && typeof n.close === "function") {
            try {
                n.close()
            } catch(e) {}
        }
        
        // 2. Forcefully and instantly remove it from the UI list
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
