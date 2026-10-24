import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: window
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: content.isOpen && NotificationDaemon.drawerPinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: content.surfaceVisible
    property alias barHeight: content.barHeight
    mask: Region {
        x: content.inputRect.x
        y: content.inputRect.y
        width: content.inputRect.width
        height: content.inputRect.height
    }
    NotificationDrawerContent {
        id: content
        onLinkActivated: url => Qt.openUrlExternally(url)
        anchors.fill: parent
    }
}
