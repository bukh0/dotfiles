//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false
    property bool closing: false
    function dismiss() {
        if (closing || clipboardBackend.busy) return
        closing = true
        window.visible = false
        Qt.quit()
    }
    IpcHandler { target: "clipboard"; function toggle(): void { root.dismiss() } }
    ClipboardService {
        id: clipboardBackend
        onCopied: pasteRequested => {
            root.closing = true
            window.visible = false
            if (pasteRequested) pasteDelay.start()
            else Qt.quit()
        }
        onPasted: Qt.quit()
        onErrorChanged: {
            if (root.closing && error) {
                Quickshell.execDetached(["notify-send", "-a", "Clipboard", "--", "Clipboard", error])
                Qt.quit()
            }
        }
    }
    Timer {
        id: pasteDelay
        interval: 180
        onTriggered: clipboardBackend.perform("paste", clipboardBackend.address)
    }
    PanelWindow {
        id: window
        property bool screenChosen: false
        function chooseInitialScreen() {
            if (screenChosen) return
            const focused = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            if (focused) { screen = focused; screenChosen = true }
            else screen = Quickshell.screens[0]
        }
        Component.onCompleted: { chooseInitialScreen(); if (!screenChosen) Hyprland.refreshMonitors() }
        Connections { target: Hyprland; function onFocusedMonitorChanged() { window.chooseInitialScreen() } }
        Connections { target: Quickshell; function onScreensChanged() { window.chooseInitialScreen() } }
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.background, 0.42)
            MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
        }
        ClipboardView {
            id: content
            service: clipboardBackend
            anchors.centerIn: parent
            width: Math.min(940, window.width - 40)
            height: Math.min(650, window.height - 48)
            onDismissed: root.dismiss()
            opacity: 0
            scale: 0.97
            Component.onCompleted: { appear.start(); Qt.callLater(() => focusSearch()) }
            ParallelAnimation {
                id: appear
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: 150 }
                NumberAnimation { target: content; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
}
