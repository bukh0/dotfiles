import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 6

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

            readonly property bool shouldShow: !isHidden(modelData)

            width: shouldShow ? 18 : 0
            height: shouldShow ? 18 : 0
            visible: shouldShow

            Image {
                anchors.fill: parent
                // Was unconditional — filtered items were decoding and
                // caching an icon nobody ever sees. No source, nothing to
                // decode or cache.
                source: trayItem.shouldShow ? trayItem.modelData.icon : ""
                sourceSize: Qt.size(36, 36)
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
