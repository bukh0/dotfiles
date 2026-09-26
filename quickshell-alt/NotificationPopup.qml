import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: popup

    property var notificationData: null
    property int displayDuration: 3000
    property bool isVisible: false

    // ── Queue ────────────────────────────────────────────────
    // A second notification arriving while one is still showing used to
    // silently overwrite it. Queue instead so nothing gets dropped.
    property var _queue: []

    property string uiFont: Theme.fontUI
    property string iconFont: Theme.fontMono

    visible: isVisible || bg.opacity > 0
    color: "transparent"

    anchors {
        top: true
        right: true
    }

    margins {
        top: 50
        right: 10
    }

    implicitWidth: 340
    implicitHeight: bg.implicitHeight

    Timer {
        id: hideTimer
        interval: popup.displayDuration
        onTriggered: popup.isVisible = false
        repeat: false
    }

    // Small gap after the fade-out so the next toast doesn't pop in
    // while the current one is still animating away.
    Timer {
        id: advanceTimer
        interval: 220
        onTriggered: popup._advanceQueue()
    }

    onIsVisibleChanged: {
        if (!isVisible && popup._queue.length > 0) advanceTimer.restart()
    }

    function _advanceQueue() {
        if (popup._queue.length === 0) return
        const next = popup._queue[0]
        popup._queue = popup._queue.slice(1)
        popup.notificationData = next
        popup.isVisible = true
        hideTimer.restart()
    }

    function showNotification(data) {
        if (popup.isVisible) {
            popup._queue = popup._queue.concat([data])
            return
        }
        popup.notificationData = data
        popup.isVisible = true
        hideTimer.restart()
    }

    Rectangle {
        id: bg
        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        x: popup.isVisible ? 0 : 20
        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        opacity: popup.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        RowLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 12

            Image {
                source: NotificationDaemon.getIconSource(popup.notificationData)
                visible: source.toString() !== ""
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignTop
                fillMode: Image.PreserveAspectFit
                clip: true
                asynchronous: true
                sourceSize: Qt.size(84, 84)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: popup.notificationData?.appName || "App"
                        color: Colors.primary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.family: popup.uiFont
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: popup._queue.length > 0
                        text: "+" + popup._queue.length
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: popup.uiFont
                    }
                }

                Text {
                    text: popup.notificationData?.summary || ""
                    color: Colors.surfaceFg
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: popup.uiFont
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: text !== ""
                }

                Text {
                    text: popup.notificationData?.body || ""
                    textFormat: Text.StyledText
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                    font.pixelSize: 12
                    font.family: popup.uiFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: text !== ""
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: hideTimer.stop()
            onExited: {
                if (popup.isVisible) hideTimer.start()
            }

            onClicked: (mouse) => {
                popup.isVisible = false
                hideTimer.stop()
            }
        }
    }
}
