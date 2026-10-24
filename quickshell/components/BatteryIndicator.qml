import QtQuick
import QtQuick.Controls
import Quickshell.Services.UPower
import "."

Item {
    id: root
    width: label.implicitWidth
    height: label.implicitHeight
    visible: hasBattery

    property int capacity: 100
    property string status: "Unknown"

    readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    readonly property bool isCharging: status === "Charging" || status === "Full"
    readonly property bool isCritical: !isCharging && capacity <= 10
    readonly property bool isLow: !isCharging && capacity <= 20

    readonly property string icon: {
        if (status === "Charging") return "󰂄"
        if (status === "Full" || status === "Not charging") return "󰚥"
        const idx = Math.min(9, Math.max(0, Math.floor(capacity / 10)))
        return icons[idx]
    }

    readonly property color iconColor: {
        if (isCharging) return Colors.primary
        if (isCritical) return Colors.error
        if (isLow) return Colors.tertiary
        return Colors.surfaceFg
    }

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: !!(device && device.ready && device.isPresent)
    readonly property real normalizedPercentage: {
        if (!root.hasBattery) return 1.0
        const value = Number(root.device.percentage)
        if (!isFinite(value)) return 0.0
        // Quickshell already normalizes UPower's percentage to 0..1.
        return Math.max(0, Math.min(1, value))
    }

    Binding {
        target: root
        property: "capacity"
        value: Math.round(root.normalizedPercentage * 100)
    }
    Binding {
        target: root
        property: "status"
        value: {
            if (!root.hasBattery) return "Full"
            if (root.device.state === UPowerDeviceState.Charging) return "Charging"
            if (root.device.state === UPowerDeviceState.FullyCharged) return "Full"
            if (root.device.state === UPowerDeviceState.PendingCharge) return "Not charging"
            return "Discharging"
        }
    }

    SequentialAnimation {
        running: root.isCritical && root.visible
        loops: Animation.Infinite
        NumberAnimation { target: label; property: "opacity"; to: 0.35; duration: 650 }
        NumberAnimation { target: label; property: "opacity"; to: 1; duration: 650 }
        onRunningChanged: if (!running) label.opacity = 1
    }
    function durationText(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0) return ""
        const minutes = Math.round(seconds / 60)
        return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m"
    }
    HoverHandler { id: hover; blocking: false }
    ToolTip {
        id: tooltip
        popupType: Popup.Window
        visible: hover.hovered
        delay: 500
        text: {
            if (!root.hasBattery) return ""
            const remaining = root.durationText(root.isCharging ? root.device.timeToFull : root.device.timeToEmpty)
            const watts = root.device.changeRate
            return root.status + " · " + root.capacity + "%"
                + (remaining ? "\n" + remaining + (root.isCharging ? " until full" : " remaining") : "")
                + (Number.isFinite(watts) && watts > 0 ? "\n" + watts.toFixed(1) + " W" : "")
        }
        contentItem: Text { text: tooltip.text; font: tooltip.font; color: tooltip.palette.toolTipText; textFormat: Text.PlainText }
    }

    Text {
        id: label
        text: root.icon + " " + root.capacity + "%"
        color: root.iconColor
        font.pixelSize: Theme.fontSizeMD
        font.family: Theme.fontMono
        font.weight: Font.Bold
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
