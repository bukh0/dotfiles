import QtQuick
import Quickshell.Io
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight

    // ── Connection icon ─────────────────────────────────────
    readonly property string status: {
        if (NetworkService.connectionType === "wifi") return NetworkService.signalIcon(NetworkService.signalStrength)
        if (NetworkService.connectionType === "ethernet") return "󰈀"
        return "󰤭"
    }

    // Matches waybar's network module: clicking just launches
    // nm-connection-editor as its own top-level window. No SNI tray item,
    // no DBusMenu, no layer-shell popup — which is exactly why waybar's
    // version never showed the slide/reposition animation Quickshell's
    // QsMenuAnchor-based popup did.
    Process {
        id: editorProc
        command: ["nm-connection-editor"]
    }

    Text {
        id: label
        text: root.status
        color: root.status === "󰤭"
            ? Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
            : mouseArea.containsMouse
                ? Colors.surfaceFg
                : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.8)
        font.pixelSize: 15
        font.family: Theme.fontMono
        font.weight: Font.Bold
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!editorProc.running) editorProc.running = true
        }
    }
}
