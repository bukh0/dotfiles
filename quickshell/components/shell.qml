//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

ShellRoot {
    id: shell
    PersistentProperties {
        id: barState
        property bool shown: true
        onShownChanged: if (!shown) NotificationDaemon.isDrawerOpen = false
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
        function setFullscreen(hidden: bool): void { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels() }
    }

    // Singletons are created lazily. Touch the ones that must run while
    // the control panel is closed (Bluetooth notifications, backlight
    // discovery) so they start with the shell.
    Component.onCompleted: {
        MusicService.initialize()
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

    Connections {
        target: Hyprland
        // Workspace hasFullscreen merges maximize and fullscreen. Refresh the
        // client mode snapshot on compositor events, without polling.
        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "openwindow" || event.name === "movewindowv2")
                Hyprland.refreshToplevels()
        }
    }

    function barVisibleOn(screen) {
        const monitor = screen ? Hyprland.monitorFor(screen) : null
        const workspace = monitor ? monitor.activeWorkspace : null
        const windows = workspace && workspace.toplevels ? workspace.toplevels.values : []
        // Hyprland's hasFullscreen includes maximized windows (mode 1).
        // Only true internal fullscreen (mode 2) should hide the bar.
        return barState.shown && !windows.some(window =>
            window.lastIpcObject && Number(window.lastIpcObject.fullscreen) === 2)
    }

    NotificationDrawer {
        id: notificationDrawer
        screen: NotificationDaemon.surfaceScreen || getActiveScreen()
        readonly property bool barShownOnScreen: shell.barVisibleOn(screen)
        barHeight: barShownOnScreen ? Theme.barTotalHeight : 0
        onBarShownOnScreenChanged: if (!barShownOnScreen) NotificationDaemon.isDrawerOpen = false
    }

    NotificationPopup {
        id: notifPopup
        barHeight: shell.barVisibleOn(screen) ? Theme.barTotalHeight : 0
    }

    Connections {
        target: NotificationDaemon
        function onTimestampsChanged() { notificationHistory.times = JSON.stringify(NotificationDaemon.timestamps) }
        function onNewNotification(data) {
            notifPopup.showNotification(data, getActiveScreen())
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
                    visible: shell.barVisibleOn(output.modelData)
                }
            }
        }
    }
}
