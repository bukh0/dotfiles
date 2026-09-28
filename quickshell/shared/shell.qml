//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

ShellRoot {
    // Singletons are created lazily. Touch the ones that must run while
    // the control panel is closed (Bluetooth notifications, backlight
    // discovery) so they start with the shell.
    Component.onCompleted: {
        BluetoothService.refresh()
        BrightnessService.discover()
    }

    function getActiveScreen() {
        const focused = Hyprland.focusedMonitor
        if (focused) {
            const found = Quickshell.screens.find(s => s.name === focused.name)
            if (found) return found
        }
        return Quickshell.screens[0]
    }

    NotificationDrawer {
        id: notificationDrawer
        screen: NotificationDaemon.surfaceScreen || getActiveScreen()
        drawerY: Theme.barTotalHeight + 4
    }

    NotificationPopup {
        id: notifPopup
        screen: getActiveScreen()
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
