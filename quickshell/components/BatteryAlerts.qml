import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property bool usable: !!(device && device.ready && device.isPresent && Number.isFinite(device.percentage))
    readonly property real percentage: usable ? device.percentage * 100 : 100
    readonly property bool discharging: usable && UPower.onBattery
    PersistentProperties {
        id: state
        property bool lowSent: false
        property bool criticalSent: false
        onLoaded: evaluate.restart()
    }
    onPercentageChanged: evaluate.restart()
    onDischargingChanged: evaluate.restart()
    Timer {
        id: evaluate
        interval: 250
        onTriggered: {
            if (!root.usable) return
            if (!root.discharging || root.percentage > 20) {
                state.lowSent = false
                state.criticalSent = false
                return
            }
            let threshold = 0
            if (root.percentage <= 5 && !state.criticalSent) {
                state.criticalSent = true; state.lowSent = true; threshold = 5
            } else if (root.percentage <= 15 && !state.lowSent) {
                state.lowSent = true; threshold = 15
            }
            if (threshold) Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", "critical", "-t", "0", "--",
                threshold === 5 ? "Battery critically low" : "Low battery",
                Math.round(root.percentage) + "% remaining. Connect the charger."])
        }
    }
    Component.onCompleted: evaluate.restart()
}
