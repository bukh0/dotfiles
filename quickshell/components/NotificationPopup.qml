import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: window
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; right: true }
    margins { top: content.barHeight + 1; right: 10 }
    color: "transparent"
    visible: content.activeCount > 0
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    property alias barHeight: content.barHeight

    function showNotification(data, targetScreen) {
        content.showNotification(data, targetScreen)
    }
    NotificationPopupContent {
        id: content
        onLinkActivated: url => Qt.openUrlExternally(url)
        width: window.width
        onScreenChanged: if (screen) window.screen = screen
    }
}
