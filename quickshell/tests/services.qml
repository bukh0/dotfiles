import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "profile" as Config

ShellRoot {
    id: root
    property QtObject mockPlayer: QtObject {
        property string dbusName: "org.mpris.MediaPlayer2.mock"
        property string identity: "Mock"
        property string trackTitle: "First\nTitle"
        property string trackArtist: "Artist"
        property string trackAlbum: "Album"
        property string trackArtUrl: ""
        property int playbackState: MprisPlaybackState.Playing
        property bool canGoPrevious: false
        property bool canGoNext: false
        property bool canTogglePlaying: false
    }
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
    // Keep the synthetic pointer outside the popup so hover does not pause timers.
    Config.NotificationPopup { id: popup; parent: scene.contentItem; x: scene.width + 10 }
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
                    battery.device = {ready: true, isPresent: true, percentage: 0.05, state: UPowerDeviceState.PendingCharge}
                    check(battery.isCritical, "pending charge concealed low battery")
                    battery.device = {ready: true, isPresent: false, percentage: 0, state: 0}
                    check(!battery.visible, "absent battery displayed as full")
                    const wifi = descendants(panel).find(item => item.toString().startsWith("WifiToggle_"))
                    check(!!wifi, "control panel did not instantiate content")
                    wifi.expanded = true
                    const music = descendants(panel).find(item => item.toString().startsWith("MusicWidget_"))
                    Config.MusicService.sourcePlayers = [root.mockPlayer]
                    check(Config.MusicService.model.count === 1, "native music model not populated")
                    check(Config.MusicService.model.get(0).title === "First\nTitle", "multiline title lost")
                    const otherPlayer = {dbusName: "other", identity: "Spotify", trackTitle: "Other song", playbackState: 1,
                                         canGoPrevious: false, canGoNext: false, canTogglePlaying: false}
                    Config.MusicService.sourcePlayers = [root.mockPlayer, otherPlayer]
                    check(Config.MusicService.selectedPlayer === root.mockPlayer.dbusName, "new player changed selection")
                    Config.MusicService.sourcePlayers = [otherPlayer]
                    check(Config.MusicService.selectedPlayer === "other", "removed player was still selected")
                    Config.MusicService.sourcePlayers = [otherPlayer, root.mockPlayer]
                    check(Config.MusicService.selectedPlayer === "other", "returning player stole selection")
                    Config.MusicService.sourcePlayers = [root.mockPlayer]
                    root.mockPlayer.trackTitle = "Next title"
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
                    check(Config.MusicService.model.get(0).title === "Next title", "MPRIS metadata change was not applied")
                    const rectangles = descendants(panel).filter(item => item.toString().startsWith("QQuickRectangle"))
                    check(rectangles[0].height <= panel.height - panel.openY, "expanded panel grew off screen")
                    check(root.networkErrors.length === 0, "network command failed: " + root.networkErrors.join("; "))
                    check(!network.busy, "connect did not release shared busy state")
                    check(network.disconnectActive(), "disconnect failed to start")
                    panel.pinned = false
                    panel.scheduleHoverClose()
                    panel.pinned = true
                    break
                case 2:
                    check(panel.isOpen && panel.pinned, "pending hover timer closed a pinned panel")
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
                    popup.dismissAll()
                    popup.persistentDisplayDuration = 100
                    popup.showNotification({notifId: 70, summary: "persistent", expireTimeout: 0})
                    popup.showNotification({notifId: 71, summary: "queued", expireTimeout: -1})
                    popup.showNotification({notifId: 71, summary: "promoted to critical", urgency: 2, expireTimeout: 0})
                    check(popup.notificationData.notifId === 71, "critical alert was blocked by persistent popup")
                    check(popup._queue.length === 0, "critical replacement stayed duplicated in queue")
                    check(popup.displayDuration === 0, "critical alert acquired expiration timeout")
                    popup.showNotification({notifId: 72, summary: "ordinary successor", expireTimeout: 5000})
                    break
                case 4:
                    check(popup.notificationData.notifId === 72, "persistent alert starved queued notification")
                    popup.persistentDisplayDuration = 2000
                    popup.showNotification({notifId: 73, summary: "waiting", expireTimeout: 5000})
                    popup.dismiss()  // schedules advanceTimer
                    popup.showNotification({notifId: 74, summary: "interrupt during fade", urgency: 2, expireTimeout: 0})
                    check(popup.notificationData.notifId === 74, "urgent alert failed during fade")
                    break
                case 5:
                    check(popup.notificationData.notifId === 74, "old advance timer overwrote critical alert")
                    check(popup._queue.length === 1 && popup._queue[0].notifId === 73, "preemption lost queued alert")
                    popup.dismiss()
                    break
                case 6:
                    check(popup.notificationData.notifId === 73, "queue failed to resume after critical dismissal")
                    popup.dismissAll()
                    check(network.connectToNetwork("needs-password", ""), "failed to start missing-password test")
                    break
                case 7:
                    check(!network.busy, "failed connection stayed busy")
                    check(network.awaitingPasswordFor === "needs-password", "stderr secrets error did not open password prompt")
                    check(Config.SysmonService.cpuPercent === "37%", "sysmon sample missing: " + Config.SysmonService.cpuPercent)
                    panel.isOpen = false
                    break
                case 8:
                    panel.isOpen = true
                    check(Config.MusicService.model.count === 1, "closing panel discarded music state")
                    check(Config.SysmonService.cpuPercent === "37%", "closing panel discarded resource state")
                    check(network.runCommand(["/nonexistent/nmcli"]), "missing executable test failed to start")
                    break
                case 9:
                    check(!network.busy, "missing executable left busy state")
                    check(root.networkErrors.includes("Could not start network command"), "missing executable had no error")
                    check(network.runCommand(["nmcli", "test-status-failure"]), "status failure setup did not start")
                    break
                case 10:
                    check(network.connectionType === "none" && !network.wifiOn && network.ssid === "" && network.activeWifiDevice === "" && network.signalStrength === 0, "failed network poll left stale state")
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
