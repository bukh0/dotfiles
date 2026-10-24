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
        // Reapply even when the next burst targets the same screen: the
        // compositor may have moved the window since the preceding burst.
        if (data && !NotificationDaemon.isDrawerOpen && content.activeCount === 0 && content._queue.length === 0 && targetScreen)
            window.screen = targetScreen
        content.showNotification(data, targetScreen)
    }
    NotificationPopupContent {
        id: content
        onLinkActivated: url => Qt.openUrlExternally(url)
        width: window.width
        onScreenChanged: if (screen) window.screen = screen
    }
}
