import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 10

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int artSize: 84
    readonly property int controlsHeight: 42
    readonly property int rowGap: 10
    readonly property int pageHeight: artSize + rowGap + controlsHeight

    ListModel { id: playersListModel }

    Process {
        id: metaPoll
        command: ["playerctl", "-a", "metadata", "--format", "{{playerName}}|{{title}}|{{artist}}|{{album}}|{{status}}|{{mpris:artUrl}}"]
        stdout: StdioCollector {
            onStreamFinished: root.applyPollResult(text)
        }
    }

    function applyPollResult(text) {
        const trimmed = text.trim()
        const parsed = []

        if (trimmed !== "") {
            const lines = trimmed.split("\n")
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split("|")
                if (parts.length >= 4) {
                    parsed.push({
                        player: parts[0] || "",
                        title: parts[1] || "Nothing playing",
                        artist: parts[2] || "",
                        album: parts[3] || "",
                        status: parts[4] || "Stopped",
                        artUrl: parts[5] || ""
                    })
                }
            }
        }

        for (let i = playersListModel.count - 1; i >= 0; i--) {
            const existingName = playersListModel.get(i).player
            const stillPresent = parsed.some(p => p.player === existingName)
            if (!stillPresent) playersListModel.remove(i)
        }

        for (let i = 0; i < parsed.length; i++) {
            const p = parsed[i]
            let modelIndex = -1
            for (let j = 0; j < playersListModel.count; j++) {
                if (playersListModel.get(j).player === p.player) {
                    modelIndex = j
                    break
                }
            }

            if (modelIndex === -1) {
                playersListModel.append(p)
                continue
            }

            const existing = playersListModel.get(modelIndex)
            if (existing.title !== p.title) playersListModel.setProperty(modelIndex, "title", p.title)
            if (existing.artist !== p.artist) playersListModel.setProperty(modelIndex, "artist", p.artist)
            if (existing.album !== p.album) playersListModel.setProperty(modelIndex, "album", p.album)
            if (existing.status !== p.status) playersListModel.setProperty(modelIndex, "status", p.status)
            if (existing.artUrl !== p.artUrl) playersListModel.setProperty(modelIndex, "artUrl", p.artUrl)
        }

        if (pager.currentIndex >= playersListModel.count) {
            pager.currentIndex = Math.max(0, playersListModel.count - 1)
        }
    }

    function pollNow() {
        if (!metaPoll.running) metaPoll.running = true
    }

    Timer {
        id: refreshDelay
        interval: 150
        onTriggered: root.pollNow()
    }

    function scheduleRefresh() {
        refreshDelay.restart()
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: root.pollNow()
    }

    onVisibleChanged: {
        if (visible) root.pollNow()
    }

    Component.onCompleted: root.pollNow()

    // --- Fallback: no players ---
    Item {
        Layout.fillWidth: true
        implicitHeight: root.artSize
        visible: playersListModel.count === 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.artSize
            height: root.artSize
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

    // --- Manual horizontal pager — one player card per page ---
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
                                id: art
                                Layout.preferredWidth: root.artSize
                                Layout.preferredHeight: root.artSize
                                Layout.alignment: Qt.AlignTop
                                radius: 10
                                color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: artUrl !== ""
                                    asynchronous: true
                                    cache: true
                                    // Optimization: Prevents high-res covers from inflating memory usage
                                    sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: artUrl === ""
                                    text: "󰎆"
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                                    font.pixelSize: 30
                                    font.family: root.fontFamily
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
                                    text: player
                                    color: Colors.primary
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

        // --- Universal WheelHandler (Supports both Horizontal and Vertical Scrolling) ---
        WheelHandler {
            id: wheelHandler
            target: null
            acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse
            property real accumPx: 0

            onWheel: (event) => {
                if (pageLockout.running) return

                // Intelligently check both horizontal and vertical inputs
                let delta = Math.abs(event.pixelDelta.x) > 0 ? event.pixelDelta.x : 0
                if (delta === 0) delta = Math.abs(event.angleDelta.x) > 0 ? event.angleDelta.x / 3 : 0
                // Fallback to vertical scrolling if no horizontal input is present
                if (delta === 0) {
                    delta = Math.abs(event.pixelDelta.y) > 0 ? event.pixelDelta.y : event.angleDelta.y / 3
                }
                if (delta === 0) return

                accumPx += delta
                const threshold = 40 

                if (accumPx <= -threshold && pager.currentIndex < pager.pageCount - 1) {
                    pager.goTo(pager.currentIndex + 1)
                    accumPx = 0
                    pageLockout.restart()
                } else if (accumPx >= threshold && pager.currentIndex > 0) {
                    pager.goTo(pager.currentIndex - 1)
                    accumPx = 0
                    pageLockout.restart()
                }
            }
        }

        Timer {
            id: pageLockout
            interval: 250
        }
    }

    // --- Page dots ---
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
