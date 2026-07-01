import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PopupWindow {
    id: popup
    color: "transparent"
    visible: false
    stayOnTop: true   // if available; if not, ignore

    property var notificationData: null
    property int displayDuration: 3000

    implicitWidth: 340
    implicitHeight: content.implicitHeight + 24

    // For testing, set a fixed position
    x: 100
    y: 100

    Timer {
        id: hideTimer
        interval: popup.displayDuration
        onTriggered: {
            console.log("Popup timer triggered, hiding")
            popup.visible = false
        }
        repeat: false
    }

    onVisibleChanged: {
        console.log("Popup visibility changed to:", visible)
        if (visible) {
            console.log("Popup data:", notificationData)
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12
            }
            spacing: 4

            Text {
                text: popup.notificationData?.appName || "App"
                color: Colors.primary
                font.pixelSize: 10
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: popup.notificationData?.summary || ""
                color: Colors.surfaceFg
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            Text {
                text: popup.notificationData?.body || ""
                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: text !== ""
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("Popup clicked, dismissing")
            visible = false
            hideTimer.stop()
        }
    }

    function showNotification(data) {
        console.log("showNotification called with data:", data)
        notificationData = data
        visible = true
        hideTimer.restart()
    }
}
