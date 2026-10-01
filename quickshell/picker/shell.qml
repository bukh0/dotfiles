//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

ShellRoot {
    id: root
    // Applying a theme replaces Colors.qml. Do not reload mid-operation.
    Component.onCompleted: Quickshell.watchFiles = false
    function dismiss() { if (!view.busy) { window.visible = false; Qt.quit() } }

    IpcHandler {
        target: "picker"
        function dismiss(): void { root.dismiss() }
    }

    PanelWindow {
        id: window
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]
        // No anchors: the compositor centres a window-sized surface, so
        // only the panel area is rendered each frame instead of the whole monitor.
        implicitWidth: Math.max(320, Math.min(820, (screen ? screen.width : 1920) - 80))
        implicitHeight: Math.max(220, Math.min(600, (screen ? screen.height : 1080) - 80))
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        PickerView {
            id: view
            anchors.fill: parent
            onDismissed: root.dismiss()
            opacity: 0
            Component.onCompleted: { appear.start(); Qt.callLater(() => focusSearch()) }
            NumberAnimation { id: appear; target: view; property: "opacity"; to: 1; duration: 120 }
        }
    }

    // Static input surfaces catch outside clicks independently of compositor
    // focus-grab support. Scrolling only repaints the small picker window.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: dismissSurface
            required property var modelData
            screen: modelData
            visible: window.visible
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell-picker-dismiss"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Leave a hole for the picker, regardless of surface stacking order.
            mask: Region {
                width: dismissSurface.width
                height: dismissSurface.height
                Region {
                    intersection: Intersection.Subtract
                    x: Math.floor((dismissSurface.width - window.width) / 2)
                    y: Math.floor((dismissSurface.height - window.height) / 2)
                    width: dismissSurface.screen === window.screen ? window.width : 0
                    height: dismissSurface.screen === window.screen ? window.height : 0
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.dismiss()
            }
        }
    }
}
