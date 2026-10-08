//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

ShellRoot {
    PersistentProperties {
        id: barState
        property bool shown: true
    }
    PersistentProperties {
        id: notificationHistory
        property string times: "{}"
        onLoaded: NotificationDaemon.restoreTimestamps(times)
    }
    IpcHandler {
        target: "bar"
        function available(): bool { return true }
        function toggle(): void { barState.shown = !barState.shown }
        function hide(): void { barState.shown = false }
        function show(): void { barState.shown = true }
        // Compatibility with older helpers: refresh real state, never latch their snapshot.
        function setFullscreen(hidden: bool): void { Hyprland.refreshWorkspaces() }
    }

    // Profiles import Colors.qml through a symlink. Watch the actual target:
    // atomic replacement does not trigger Quickshell's symlink-file watcher.
    FileView {
        path: Quickshell.shellPath("../../components/Colors.qml")
        watchChanges: true
        onFileChanged: Quickshell.reload(false)
    }

    // Singletons are created lazily. Touch the ones that must run while
    // the control panel is closed (Bluetooth notifications, backlight
    // discovery) so they start with the shell.
    Component.onCompleted: {
        MusicService.initialize()
        SysmonService.initialize()
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
        function onTimestampsChanged() { notificationHistory.times = JSON.stringify(NotificationDaemon.timestamps) }
        function onNewNotification(data) {
            notifPopup.showNotification(data)
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                id: output
                required property var modelData

                Bar {
                    id: bar
                    screen: modelData
                    visible: barState.shown
                }
            }
        }
    }
}
