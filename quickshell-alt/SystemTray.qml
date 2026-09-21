import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 6

    // Icons your own widgets already replace with custom UI:
    // NetworkIndicator/WifiToggle cover nm-applet, BluetoothToggle covers
    // blueman. Showing the raw tray icon alongside the custom one is just
    // duplicate information — filter them out here instead of hiding them
    // some other way, so any *other* tray app (Discord, Telegram, etc.)
    // still shows normally.
    readonly property var hiddenIdPatterns: ["nm-applet", "networkmanager"]

    function isHidden(item) {
        const id = (item.id || "").toLowerCase()
        const title = (item.title || "").toLowerCase()
        return hiddenIdPatterns.some(p => id.includes(p) || title.includes(p))
    }

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property SystemTrayItem modelData

            // Collapse to zero size instead of just setting visible: false —
            // RowLayout still reserves layout space for an invisible Item,
            // which would leave a gap where the hidden icon used to be.
            readonly property bool shouldShow: !isHidden(modelData)

            width: shouldShow ? 18 : 0
            height: shouldShow ? 18 : 0
            visible: shouldShow

            Image {
                anchors.fill: parent
                source: trayItem.modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        trayItem.modelData.activate()
                    else
                        trayItem.modelData.secondaryActivate()
                }
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
