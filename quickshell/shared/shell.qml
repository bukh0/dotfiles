//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

ShellRoot {
    NotificationDrawer {
        id: notificationDrawer
        screen: NotificationDaemon.surfaceScreen || ToplevelManager.activeToplevel?.screen || Quickshell.screens[0]
        drawerY: Theme.barHeight + 4
    }

    NotificationPopup {
        id: notifPopup
        screen: NotificationDaemon.surfaceScreen || ToplevelManager.activeToplevel?.screen || Quickshell.screens[0]
    }

    Connections {
        target: NotificationDaemon
        function onNewNotification(data) {
            notifPopup.showNotification(data)
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                required property var modelData

                Bar {
                    id: bar
                    screen: modelData
                }
            }
        }
    }
}
