import QtQuick
import Quickshell
import "profile" as Config

ShellRoot {
    id: root
    property int step: 0
    property var networkErrors: []
    Connections {
        target: Config.NetworkService
        function onCommandError(message) { root.networkErrors.push(message) }
    }
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    Window { id: scene; width: 800; height: 600; visible: true }
    Config.NotificationPopup { id: popup; parent: scene.contentItem }
    Config.BatteryIndicator { id: battery; parent: scene.contentItem }
    Config.ControlPanel { id: panel; parent: scene.contentItem; width: 800; height: 600; isOpen: true; pinned: true }
    function descendants(item) {
        let items = []
        for (const child of item.children || []) items = items.concat([child], descendants(child))
        return items
    }
    Component.onCompleted: Config.NetworkService.scan()
    Timer {
        interval: 600
        running: true
        repeat: true
        onTriggered: {
            try {
                const network = Config.NetworkService
                switch (root.step++) {
                case 0:
                    battery.device = {ready: true, isPresent: true, percentage: 0.75, state: 2}
                    check(battery.capacity === 75, "battery percentage scaled twice")
                    check(battery.visible, "present battery hidden")
                    battery.device = {ready: true, isPresent: false, percentage: 0, state: 0}
                    check(!battery.visible, "absent battery displayed as full")
                    const wifi = descendants(panel).find(item => item.toString().startsWith("WifiToggle_"))
                    check(!!wifi, "control panel did not instantiate content")
                    wifi.expanded = true
                    const music = descendants(panel).find(item => item.toString().startsWith("MusicWidget_"))
                    music.applyPollResult("mock\u001finstance\u001fFirst\nTitle\u001fArtist\u001fAlbum\u001fPlaying\u001fimage://test/art\u001e\n")
                    check(Object.keys(music._lastTracks).length === 1, "multiline music metadata broke the player record")
                    check(music._lastTracks["mock\u001einstance"].includes("First\\nTitle"), "multiline title was truncated")
                    music.applyPollResult("mock\u001finstance\u001fNext title\u001fArtist\u001fAlbum\u001fPlaying\u001f\u001e\n")
                    check(Object.keys(music._lastSnapshot).length === 0, "previous track's artwork leaked into next track")
                    check(network.parseNmcliFields("a\\:b:c\\\\d").join("|") === "a:b|c\\d", "nmcli escaping failed")
                    check(network.wifiOn, "Wi-Fi radio state failed")
                    check(network.connectionType === "wifi", "connection state failed")
                    check(network.activeWifiDevice === "wlan1", "active Wi-Fi device selection failed")
                    check(network.networks.length === 4, "prototype-named SSIDs were lost")
                    check(network.networks[0].ssid === "active", "weak active network sorted below others")
                    const spaced = network.networks.find(n => n.ssid === " spaced ")
                    check(spaced && !spaced.security, "SSID spaces or open-network security was corrupted")
                    check(network.connectToNetwork(" spaced ", "test-password"), "connect failed to start")
                    check(network.busy, "connection did not hold shared busy state")
                    check(!network.toggleWifiRadio(), "radio operation raced with connection")
                    break
                case 1:
                    const rectangles = descendants(panel).filter(item => item.toString().startsWith("QQuickRectangle"))
                    check(rectangles[0].height <= panel.height - panel.openY, "expanded panel grew off screen")
                    check(root.networkErrors.length === 0, "network command failed: " + root.networkErrors.join("; "))
                    check(!network.busy, "connect did not release shared busy state")
                    check(network.disconnectActive(), "disconnect failed to start")
                    break
                case 2:
                    check(root.networkErrors.length === 0, "disconnect failed: " + root.networkErrors.join("; "))
                    check(!network.busy, "disconnect did not settle")
                    popup.showNotification({notifId: 1, summary: "first", expireTimeout: 0})
                    popup.showNotification({notifId: 2, summary: "queued", expireTimeout: -1})
                    popup.showNotification({notifId: 2, summary: "updated queue", expireTimeout: -1})
                    check(popup._queue.length === 1 && popup._queue[0].summary === "updated queue", "queued replacement duplicated notification")
                    popup.showNotification({notifId: 1, summary: "updated first", expireTimeout: 0})
                    check(popup.notificationData.summary === "updated first", "visible replacement was stale")
                    check(popup.displayDuration === 0, "persistent notification acquired timeout")
                    Config.NotificationDaemon.notificationRemoved(2)
                    check(popup._queue.length === 0, "dismissed notification stayed queued")
                    Config.NotificationDaemon.notificationRemoved(1)
                    check(!popup.isVisible, "dismissed notification stayed visible")
                    popup.showNotification({notifId: 3, expireTimeout: 25})
                    break
                case 3:
                    check(!popup.isVisible, "timed notification did not expire")
                    console.log("REGRESSION PASS: services")
                    Qt.quit()
                }
            } catch (error) {
                console.error("REGRESSION FAIL:", error.message)
                Qt.quit()
            }
        }
    }
}
