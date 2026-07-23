import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: popup

    property var notificationData: null
    property int displayDuration: 3000
    property bool isVisible: false

    color: "transparent"
    visible: isVisible

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

    Rectangle {
        id: bg
        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: popup.isVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ColumnLayout {
            id: content
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
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

        MouseArea {
            anchors.fill: parent
            onClicked: {
                popup.isVisible = false
                hideTimer.stop()
            }
        }
    }

    function showNotification(data) {
        notificationData = data
        isVisible = true
        hideTimer.restart()
    }
}
