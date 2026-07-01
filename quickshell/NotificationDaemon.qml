pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property var notifications: []
    property bool isDrawerOpen: false

    function toggleDrawer() {
        console.log("DEBUG: Drawer toggle called. Current state:", isDrawerOpen);
        isDrawerOpen = !isDrawerOpen;
    }

    function clearAll() {
        for (let i = root.notifications.length - 1; i >= 0; i--) {
            let n = root.notifications[i]
            if (n && typeof n === "object" && typeof n.close === "function") {
                try {
                    n.close()
                } catch (e) {
                    console.warn("Error closing notification:", e)
                }
            }
        }
        root.notifications = []
    }

    NotificationServer {
        id: server
        onNotification: notif => {
            console.log("NOTIFICATION RECEIVED: " + notif.summary)

            let data = {
                summary: notif.summary || "",
                body: notif.body || "",
                appName: notif.appName || "",
                close: function() {
                    notif.close()
                }
            }

            root.notifications = [data].concat(root.notifications)

            notif.closed.connect(() => {
                root.notifications = root.notifications.filter(n => n !== data)
            })
        }
    }
}
