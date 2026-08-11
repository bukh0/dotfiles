import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 10

    // ── Constants & configuration ──────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int artSize: 84
    readonly property int controlsHeight: 42
    readonly property int rowGap: 10
    readonly property int pageHeight: artSize + rowGap + controlsHeight

    property int pollingInterval: 2000         // ms between automatic polls
    property int scrollThreshold: 30           // pixels/delta for page change

    // Centralized status strings
    readonly property string statusPlaying: "Playing"
    readonly property string statusPaused: "Paused"
    readonly property string statusStopped: "Stopped"

    function statusWeight(s) {
        return s === statusPlaying ? 2 : s === statusPaused ? 1 : 0
    }
    function statusIcon(s) {
        return s === statusPlaying ? "󰏤" : "󰐊"
    }
    function statusLabel(s) {
        return s === statusPlaying ? "▶ playing" : s === statusPaused ? "❚❚ paused" : s
    }

    // ── Inline MediaButton component ───────────────────────────
    component MediaButton: Rectangle {
        id: btn

        property string icon: ""
        property string label: ""   
        property int size: 17
        property int boxSize: 34
        property var command: []
        property string iconFont: root.fontFamily
        signal clicked()

        width: boxSize
        height: boxSize
        radius: 8

        color: tap.pressed
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
            : hover.hovered
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Accessible.role: Accessible.Button
        Accessible.name: btn.label !== "" ? btn.label : "Media control"
        Accessible.onPressAction: btn.activate()

        activeFocusOnTab: true
        Keys.onReturnPressed: btn.activate()
        Keys.onSpacePressed: btn.activate()

        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: Colors.surfaceFg
            font.pixelSize: btn.size
            font.family: btn.iconFont
        }

        Process {
            id: proc
            command: btn.command
            stderr: StdioCollector {
                onStreamFinished: {
                    const err = text.trim()
                    if (err.length > 0) console.warn("playerctl control error:", err)
                }
            }
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap
            onTapped: btn.activate()
        }

        function activate() {
            if (btn.command.length > 0 && !proc.running) {
                proc.running = true
                btn.clicked()
            }
        }
    }

    // ── Data model ─────────────────────────────────────────────
    ListModel { id: playersListModel }

    // ── Playerctl process ──────────────────────────────────────
    Process {
        id: metaPoll
        command: ["playerctl", "-a", "metadata", "--format", "{{playerName}}\u001f{{title}}\u001f{{artist}}\u001f{{album}}\u001f{{status}}\u001f{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: root.applyPollResult(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err.length > 0) console.warn("playerctl poll error:", err)
            }
        }
    }

    // ── Model update (with Spotify Priority & Smart fallback) ──
    property var _lastSnapshot: ({})   

    property string _pendingPlayer: ""
    property string _pendingStatus: ""
    property real _pendingSince: 0
    // Increased to 1.2s to fully absorb Spotify Connect's network ping-pong
    readonly property int pendingTimeoutMs: 1200

    function applyPollResult(rawText) {
        const trimmed = rawText.trim()
        if (trimmed === "") {
            playersListModel.clear()
            return
        }

        const parsed = []
        const lines = trimmed.split("\n")
        const now = Date.now()
        const isLockActive = root._pendingPlayer !== "" && (now - root._pendingSince) < root.pendingTimeoutMs
        if (root._pendingPlayer !== "" && !isLockActive) {
            root._pendingPlayer = ""
        }

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].trim() === "") continue

            const parts = lines[i].split("\u001f")
            if (parts.length < 5) continue

            const player = parts[0].trim()
            const title = parts[1].trim() || "Nothing playing"
            const artist = parts[2].trim()
            const album = parts[3].trim()
            const artUrl = parts.slice(5).join("\u001f").trim()

            const rawStatus = parts[4].trim()
            const actualStatus = rawStatus !== ""
                ? rawStatus.charAt(0).toUpperCase() + rawStatus.slice(1).toLowerCase()
                : root.statusStopped

            let effectiveStatus = actualStatus

            // Evaluate pending lock during parsing so the sorting algorithm sees the optimistic state
            if (isLockActive && player === root._pendingPlayer) {
                // DO NOT release the lock early! 
                // Stubbornly hold the optimistic state for the entire 1200ms timeout.
                // This absorbs Spotify Connect's erratic MPRIS bouncing entirely.
                effectiveStatus = root._pendingStatus
            }

            parsed.push({ player, title, artist, album, status: effectiveStatus, artUrl })
        }

        // ── SPOTIFY FIRST, THEN SMART STATUS SORTING ───────────
        parsed.sort((a, b) => {
            // 1. Absolute Priority: Spotify
            const aIsSpotify = a.player.toLowerCase().includes("spotify")
            const bIsSpotify = b.player.toLowerCase().includes("spotify")
            if (aIsSpotify && !bIsSpotify) return -1
            if (!aIsSpotify && bIsSpotify) return 1

            // 2. Secondary Priority: Status (Playing > Paused > Stopped)
            const wA = root.statusWeight(a.status)
            const wB = root.statusWeight(b.status)
            if (wA > wB) return -1
            if (wA < wB) return 1

            return 0
        })

        // Track what the user is currently looking at so the UI doesn't jump
        let viewedPlayer = ""
        if (playersListModel.count > 0 && pager.currentIndex >= 0 && pager.currentIndex < playersListModel.count) {
            viewedPlayer = playersListModel.get(pager.currentIndex).player
        }

        let cacheUpdated = false
        const newSnapshot = Object.assign({}, root._lastSnapshot)
        const parsedNames = new Set(parsed.map(p => p.player))

        // 1. Remove vanished players FIRST
        for (let i = playersListModel.count - 1; i >= 0; i--) {
            if (!parsedNames.has(playersListModel.get(i).player)) {
                playersListModel.remove(i, 1)
            }
        }

        // 2. Build the index map
        const existingMap = new Map()
        for (let i = 0; i < playersListModel.count; i++) {
            existingMap.set(playersListModel.get(i).player, i)
        }

        // 3. Add or Update players
        for (let i = 0; i < parsed.length; i++) {
            const p = parsed[i]

            if (existingMap.has(p.player)) {
                const idx = existingMap.get(p.player)
                const cur = playersListModel.get(idx)

                if (cur.title !== p.title) playersListModel.setProperty(idx, "title", p.title)
                if (cur.artist !== p.artist) playersListModel.setProperty(idx, "artist", p.artist)
                if (cur.album !== p.album) playersListModel.setProperty(idx, "album", p.album)
                if (cur.status !== p.status) playersListModel.setProperty(idx, "status", p.status)

                if (cur.artUrl !== p.artUrl) {
                    playersListModel.setProperty(idx, "artUrl", p.artUrl)
                    if (p.artUrl !== "") {
                        newSnapshot[p.player] = p.artUrl
                        cacheUpdated = true
                    }
                }
            } else {
                playersListModel.append(p)
                existingMap.set(p.player, playersListModel.count - 1)
                if (p.artUrl !== "") {
                    newSnapshot[p.player] = p.artUrl
                    cacheUpdated = true
                }
            }
        }

        if (cacheUpdated) {
            root._lastSnapshot = newSnapshot
        }

        // 4. Reorder list model to match parsed array strictly
        for (let i = 0; i < parsed.length; i++) {
            if (playersListModel.get(i).player !== parsed[i].player) {
                for (let j = i + 1; j < playersListModel.count; j++) {
                    if (playersListModel.get(j).player === parsed[i].player) {
                        playersListModel.move(j, i, 1)
                        break
                    }
                }
            }
        }

        // 5. Restore viewport to the player the user was looking at
        if (viewedPlayer !== "") {
            let foundIdx = -1
            for (let i = 0; i < playersListModel.count; i++) {
                if (playersListModel.get(i).player === viewedPlayer) {
                    foundIdx = i
                    break
                }
            }
            if (foundIdx !== -1 && foundIdx !== pager.currentIndex) {
                pager.currentIndex = foundIdx
            }
        }

        // Fallback boundary check
        if (pager.currentIndex >= playersListModel.count) {
            pager.currentIndex = Math.max(0, playersListModel.count - 1)
        }
    }

    // ── Polling control ────────────────────────────────────────
    function pollNow() {
        if (!metaPoll.running) metaPoll.running = true
    }

    Timer {
        id: debounceTimer
        interval: 120
        onTriggered: root.pollNow()
    }

    function scheduleRefresh() {
        debounceTimer.restart()
    }

    Timer {
        id: autoPollTimer
        interval: root.pollingInterval
        running: root.visible
        repeat: true
        onTriggered: root.pollNow()
    }

    onVisibleChanged: {
        if (visible) {
            scheduleRefresh()
            autoPollTimer.restart()
        } else {
            autoPollTimer.stop()
            debounceTimer.stop()
        }
    }

    // ── Post-action reconciliation ───────────────────────────────
    Timer {
        id: reconcileTimer
        interval: 300
        repeat: true
        property int triesLeft: 0
        onTriggered: {
            triesLeft -= 1
            root.pollNow()
            if (triesLeft <= 0) stop()
        }
    }

    function scheduleReconcile() {
        root.pollNow()
        reconcileTimer.triesLeft = 4 // Polls at 300ms, 600ms, 900ms, 1200ms
        reconcileTimer.restart()
    }

    function optimisticToggle(player) {
        for (let i = 0; i < playersListModel.count; i++) {
            if (playersListModel.get(i).player === player) {
                const cur = playersListModel.get(i).status
                const next = cur === root.statusPlaying ? root.statusPaused : root.statusPlaying
                
                playersListModel.setProperty(i, "status", next)
                root._pendingPlayer = player
                root._pendingStatus = next
                root._pendingSince = Date.now()
                break
            }
        }
    }

    Component.onCompleted: root.pollNow()

    // ── Empty state placeholder ────────────────────────────────
    Item {
        Layout.fillWidth: true
        implicitHeight: root.artSize
        visible: playersListModel.count === 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.artSize; height: root.artSize
            radius: 10
            color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                font.pixelSize: 30
                font.family: root.fontFamily
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.artSize + 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Nothing playing"
            color: Colors.surfaceFg
            font.pixelSize: 15
            font.family: root.fontFamily
            font.weight: Font.Medium
        }
    }

    // ── Pager with improved touch/swipe & keyboard support ───
    Item {
        id: pager
        Layout.fillWidth: true
        implicitHeight: root.pageHeight
        visible: playersListModel.count > 0
        clip: true
        focus: true

        property int currentIndex: 0
        readonly property int pageCount: playersListModel.count

        function goTo(index) {
            currentIndex = Math.max(0, Math.min(pageCount - 1, index))
        }

        TapHandler {
            onTapped: pager.forceActiveFocus()
        }

        Row {
            id: pagesRow
            x: -pager.currentIndex * pager.width
            height: pager.height
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Repeater {
                model: playersListModel

                delegate: Item {
                    required property string player
                    required property string title
                    required property string artist
                    required property string album
                    required property string status
                    required property string artUrl

                    width: pager.width
                    height: pager.height

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: root.rowGap

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                id: artBox
                                Layout.preferredWidth: root.artSize
                                Layout.preferredHeight: root.artSize
                                Layout.alignment: Qt.AlignTop
                                radius: 10
                                color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                                clip: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: artImage.status !== Image.Ready
                                    text: "󰎆"
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                                    font.pixelSize: 30
                                    font.family: root.fontFamily
                                }

                                Image {
                                    id: artImage
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)

                                    property string stableArt: artUrl !== "" ? artUrl : (root._lastSnapshot[player] || "")
                                    source: stableArt

                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    opacity: artImage.status === Image.Ready ? 1 : 0
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: title
                                    color: Colors.surfaceFg
                                    font.pixelSize: 15
                                    font.family: root.fontFamily
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: artist !== "" || album !== ""
                                    text: artist + (artist !== "" && album !== "" ? " • " : "") + album
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                                    font.pixelSize: 12
                                    font.family: root.fontFamily
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: player + " · " + root.statusLabel(status)
                                    color: status === root.statusPlaying ? Colors.primary : Colors.surfaceFg
                                    font.pixelSize: 10
                                    font.family: root.fontFamily
                                    font.weight: Font.Bold
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            MediaButton {
                                icon: "󰒮"
                                label: "Previous track"
                                size: 21
                                boxSize: 36
                                command: ["playerctl", "-p", player, "previous"]
                                onClicked: root.scheduleReconcile()
                            }

                            MediaButton {
                                icon: root.statusIcon(status)
                                label: status === root.statusPlaying ? "Pause" : "Play"
                                size: 25
                                boxSize: 42
                                command: ["playerctl", "-p", player, "play-pause"]
                                onClicked: {
                                    root.optimisticToggle(player)
                                    root.scheduleReconcile()
                                }
                            }

                            MediaButton {
                                icon: "󰒭"
                                label: "Next track"
                                size: 21
                                boxSize: 36
                                command: ["playerctl", "-p", player, "next"]
                                onClicked: root.scheduleReconcile()
                            }
                        }
                    }
                }
            }
        }

        // ── Multi-input scroll handler ──────────────────────────
        WheelHandler {
            id: wheelHandler
            target: null
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse | PointerDevice.TouchScreen
            property real accumulated: 0

            onWheel: function(wheelEvent) {
                if (pageLockout.running) return

                const angleDelta = wheelEvent.angleDelta.y || wheelEvent.angleDelta.x
                if (angleDelta !== 0) {
                    accumulated += angleDelta / 8
                } else {
                    const pixelDelta = wheelEvent.pixelDelta.y || wheelEvent.pixelDelta.x
                    if (pixelDelta === 0) return
                    accumulated += pixelDelta
                }

                const threshold = root.scrollThreshold

                while (accumulated >= threshold && pager.currentIndex > 0) {
                    pager.goTo(pager.currentIndex - 1)
                    accumulated -= threshold
                    pageLockout.restart()
                }
                while (accumulated <= -threshold && pager.currentIndex < pager.pageCount - 1) {
                    pager.goTo(pager.currentIndex + 1)
                    accumulated += threshold
                    pageLockout.restart()
                }

                if (Math.abs(accumulated) > threshold * 2) accumulated = 0
                wheelEvent.accepted = true
            }
        }

        // ── Keyboard navigation ──────────────────────────────────
        Keys.onPressed: function(keyEvent) {
            if (keyEvent.key === Qt.Key_Left) {
                pager.goTo(pager.currentIndex - 1)
                keyEvent.accepted = true
            } else if (keyEvent.key === Qt.Key_Right) {
                pager.goTo(pager.currentIndex + 1)
                keyEvent.accepted = true
            }
        }

        Timer {
            id: pageLockout
            interval: 200
        }
    }

    // ── Page indicator dots ────────────────────────────────────
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: playersListModel.count > 1
        spacing: 6

        Repeater {
            model: playersListModel.count

            delegate: Rectangle {
                implicitWidth: index === pager.currentIndex ? 16 : 6
                implicitHeight: 6
                radius: 3
                color: index === pager.currentIndex
                    ? Colors.primary
                    : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on implicitWidth { NumberAnimation { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: pager.goTo(index)
                }
            }
        }
    }
}
