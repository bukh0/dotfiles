import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 10

    // ── Constants & configuration ──────────────────────────────
    readonly property string fontFamily: Theme.fontMono
    readonly property int artSize: Theme.mediaArtSize
    readonly property int controlsHeight: 42
    readonly property int rowGap: 10
    readonly property int pageHeight: artSize + rowGap + controlsHeight

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

    // Same normalization NotificationDaemon.getIconSource() already does —
    // some MPRIS players hand back a bare filesystem path instead of a
    // proper file:// URI for mpris:artUrl, which Image.source can't load.
    function normalizeArt(raw) {
        if (!raw) return ""
        const s = raw.toString()
        return s.startsWith("/") ? "file://" + s : s
    }

    // ── Inline MediaButton component ───────────────────────────
    component MediaButton: Rectangle {
        id: btn

        property string icon: ""
        property string label: ""
        property int size: 17
        property int         boxSize: Theme.mediaControlSize
        property string iconFont: root.fontFamily
        signal clicked()

        width: boxSize
        height: boxSize
        radius: Theme.controlRadius

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

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap
            onTapped: btn.activate()
        }

        function activate() {
            if (btn.enabled) btn.clicked()
        }
    }

    readonly property var playersListModel: MusicService.model

    // ── Empty state placeholder ────────────────────────────────
    Item {
        Layout.fillWidth: true
        implicitHeight: root.artSize
        visible: playersListModel.count === 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.artSize; height: root.artSize
            radius: Theme.mediaArtworkRadius
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

        readonly property int currentIndex: MusicService.selectedIndex
        readonly property int pageCount: playersListModel.count

        function goTo(index) {
            if (pageCount > 0) MusicService.selectedPlayer = playersListModel.get(Math.max(0, Math.min(pageCount - 1, index))).player
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
                    required property string playerName
                    readonly property var backend: MusicService.findPlayer(player)
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
                                radius: Theme.mediaArtworkRadius
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

                                    property string stableArt: root.normalizeArt(artUrl)
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
                                    textFormat: Text.PlainText
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
                                    textFormat: Text.PlainText
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.6)
                                    font.pixelSize: 12
                                    font.family: root.fontFamily
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: playerName + " · " + root.statusLabel(status)
                                    textFormat: Text.PlainText
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
                                enabled: backend && backend.canGoPrevious
                                onClicked: backend.previous()
                            }

                            MediaButton {
                                icon: root.statusIcon(status)
                                label: status === root.statusPlaying ? "Pause" : "Play"
                                size: 25
                                boxSize: root.controlsHeight
                                enabled: backend && backend.canTogglePlaying
                                onClicked: backend.togglePlaying()
                            }

                            MediaButton {
                                icon: "󰒭"
                                label: "Next track"
                                size: 21
                                boxSize: 36
                                enabled: backend && backend.canGoNext
                                onClicked: backend.next()
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
                implicitWidth: index === pager.currentIndex ? Theme.mediaDotActiveWidth : Theme.mediaDotWidth
                implicitHeight: Theme.mediaDotHeight
                radius: Theme.mediaDotRadius
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
