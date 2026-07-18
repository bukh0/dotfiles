import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: controlPanel

    property bool isOpen: false
    visible: isOpen
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: {
        if (visible) {
            bgCloser.forceActiveFocus()
        }
    }

    MouseArea {
        id: bgCloser
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        Keys.onEscapePressed: controlPanel.isOpen = false
        onClicked: controlPanel.isOpen = false
    }

    Rectangle {
        id: drawerBg
        width: 320
        height: contentCol.implicitHeight + 32
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        
        x: (parent.width - width) / 2
        y: controlPanel.isOpen ? 52 : 30
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        
        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: controlPanel.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
        }

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
