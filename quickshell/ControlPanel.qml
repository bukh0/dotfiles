import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PopupWindow {
    id: controlPanel

    property bool isOpen: false

    implicitWidth: 320
    implicitHeight: contentCol.implicitHeight + 32
    visible: isOpen
    color: "transparent"

    function toggle() {
        isOpen = !isOpen
    }

    Rectangle {
        id: drawerBg
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(
            Colors.surfaceContainer.r,
            Colors.surfaceContainer.g,
            Colors.surfaceContainer.b,
            0.97
        )
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
            }
            spacing: 12

            MusicWidget {}

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
            }

            VolumeSlider {}
            BrightnessSlider {}

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
            }

            WifiToggle {}
            BluetoothToggle {}

            Item { height: 4 }
        }
    }
}
