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

    // ── Data model ─────────────────────────────────────────────
    ListModel { id: playersListModel }

    // ── Playerctl process (used once per poll) ─────────────────
    Process {
        id: metaPoll
        command: ["playerctl", "-a", "metadata", "--format", "{{playerName}}|{{title}}|{{artist}}|{{album}}|{{status}}|{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: root.applyPollResult(text)
        }
    }

    // ── Efficient model update logic ──────────────────────────
    function applyPollResult(rawText) {
        const trimmed = rawText.trim()
        const parsed = []

        if (trimmed !== "") {
            const lines = trimmed.split("\n")
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i]
                const firstSep = line.indexOf("|")
                const secondSep = line.indexOf("|", firstSep + 1)
                const thirdSep = line.indexOf("|", secondSep + 1)
                const fourthSep = line.indexOf("|", thirdSep + 1)
                const fifthSep = line.indexOf("|", fourthSep + 1)

                if (firstSep === -1) continue  // malformed line

                const player = line.substring(0, firstSep).trim()
                const title = line.substring(firstSep + 1, secondSep !== -1 ? secondSep : line.length).trim() || "Nothing playing"
                const artist = secondSep !== -1 ? line.substring(secondSep + 1, thirdSep !== -1 ? thirdSep : line.length).trim() : ""
                const album = thirdSep !== -1 ? line.substring(thirdSep + 1, fourthSep !== -1 ? fourthSep : line.length).trim() : ""
                const status = fourthSep !== -1 ? line.substring(fourthSep + 1, fifthSep !== -1 ? fifthSep : line.length).trim() : "Stopped"
                const artUrl = fifthSep !== -1 ? line.substring(fifthSep + 1).trim() : ""

                parsed.push({ player, title, artist, album, status, artUrl })
            }
        }

        // Fast lookup: player name -> model index
        const existingMap = new Map()
        for (let i = 0; i < playersListModel.count; i++) {
            existingMap.set(playersListModel.get(i).player, i)
        }

        // Remove vanished players
        const parsedNames = new Set(parsed.map(p => p.player))
        for (const [name, idx] of existingMap.entries()) {
            if (!parsedNames.has(name)) {
                playersListModel.remove(idx, 1)
                existingMap.delete(name)
            }
        }

        // Add new / update existing
        for (const p of parsed) {
            if (existingMap.has(p.player)) {
                const idx = existingMap.get(p.player)
                const cur = playersListModel.get(idx)
                if (cur.title !== p.title) playersListModel.setProperty(idx, "title", p.title)
                if (cur.artist !== p.artist) playersListModel.setProperty(idx, "artist", p.artist)
                if (cur.album !== p.album) playersListModel.setProperty(idx, "album", p.album)
                if (cur.status !== p.status) playersListModel.setProperty(idx, "status", p.status)
                if (cur.artUrl !== p.artUrl) playersListModel.setProperty(idx, "artUrl", p.artUrl)
            } else {
                playersListModel.append(p)
            }
        }

        // Keep pager in bounds
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
        running: root.visible && Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: root.pollNow()
    }

    onVisibleChanged: {
        if (visible) {
            scheduleRefresh()
            autoPollTimer.restart()
        } else {
            autoPollTimer.stop()
        }
    }

    Component.onCompleted: root.pollNow()
    Component.onDestruction: {
        autoPollTimer.stop()
        debounceTimer.stop()
    }

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

    // ── Pager with individual player cards ─────────────────────
    Item {
        id: pager
        Layout.fillWidth: true
        implicitHeight: root.pageHeight
        visible: playersListModel.count > 0
        clip: true

        property int currentIndex: 0
        readonly property int pageCount: playersListModel.count

        function goTo(index) {
            currentIndex = Math.max(0, Math.min(pageCount - 1, index))
        }

        // Movable row of pages (using parent width to avoid uninitialized width glitches)
        Row {
            id: pagesRow
            x: -pager.currentIndex * root.width
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

                    width: root.width
                    height: pager.height

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: root.rowGap

                        // Player info row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // Album art with placeholder and memory optimization
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
                                    source: artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)

                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    opacity: status === Image.Ready ? 1 : 0
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
                                    text: player + " · " + (status === "Playing" ? "▶ playing" : status === "Paused" ? "❚❚ paused" : status)
                                    color: status === "Playing" ? Colors.primary : Colors.surfaceFg
                                    font.pixelSize: 10
                                    font.family: root.fontFamily
                                    font.weight: Font.Bold
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Playback controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            MediaButton {
                                icon: "󰒮"
                                size: 21
                                boxSize: 36
                                command: ["playerctl", "-p", player, "previous"]
                                onClicked: root.scheduleRefresh()
                            }

                            MediaButton {
                                icon: status === "Playing" ? "󰏤" : "󰐊"
                                size: 25
                                boxSize: 42
                                command: ["playerctl", "-p", player, "play-pause"]
                                onClicked: root.scheduleRefresh()
                            }

                            MediaButton {
                                icon: "󰒭"
                                size: 21
                                boxSize: 36
                                command: ["playerctl", "-p", player, "next"]
                                onClicked: root.scheduleRefresh()
                            }
                        }
                    }
                }
            }
        }

        // ── Scroll handling (mouse wheel & touchpad) ──────────
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            property real accumulated: 0

            onWheel: (event) => {
                if (pageLockout.running) return

                let delta = event.angleDelta.y || event.angleDelta.x
                if (delta === 0) {
                    delta = event.pixelDelta.y || event.pixelDelta.x
                    if (delta === 0) return
                }

                accumulated += delta / 8
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
                event.accepted = true
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
