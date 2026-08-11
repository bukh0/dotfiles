import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: popup

    property var notificationData: null
    property int displayDuration: 4000 // Extended slightly, 3s is often too fast
    property bool isVisible: false

    property string uiFont: "sans-serif"
    property string iconFont: "JetBrainsMono Nerd Font"

    // Keep window alive until fade animation finishes
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

    // Reuse icon logic from the drawer
    function getIconSource(data) {
        if (!data) return "";
        if (data.image) {
            const img = data.image.toString();
            return img.startsWith("/") ? "file://" + img : img;
        }
        if (data.appIcon) {
            const icon = data.appIcon.toString();
            if (icon.startsWith("/")) return "file://" + icon;
            return Quickshell.iconPath(icon); 
        }
        return "";
    }

    Rectangle {
        id: bg
        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        // Slide effect alongside fade
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
            
            // IMAGE PREVIEW
            Image {
                source: popup.getIconSource(popup.notificationData)
                visible: source.toString() !== ""
                Layout.preferredWidth: 42 
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignTop
                fillMode: Image.PreserveAspectFit 
                clip: true
                asynchronous: true
                sourceSize: Qt.size(84, 84) 
            }

            // TEXT CONTENT
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

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
                    text: popup.notificationData?.summary || ""
                    color: Colors.surfaceFg
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: popup.uiFont
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0 // Forces wrap inside Layout
                    visible: text !== ""
                }

                Text {
                    text: popup.notificationData?.body || ""
                    textFormat: Text.StyledText // Support DBus HTML styling
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                    font.pixelSize: 12
                    font.family: popup.uiFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 4 // Prevent massive text walls
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0 // Forces wrap inside Layout
                    visible: text !== ""
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            
            // Pause timer on hover so the user can read it, resume on exit
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

    function showNotification(data) {
        notificationData = data
        isVisible = true
        hideTimer.restart()
    }
}
