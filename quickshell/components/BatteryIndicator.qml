import QtQuick
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
        if (status === "Full") return "󰚥"
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

    Timer {
        interval: 1000
        running: root.isCritical
        repeat: true
        onTriggered: label.opacity = label.opacity === 1 ? 0.3 : 1
        onRunningChanged: if (!running) label.opacity = 1
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
