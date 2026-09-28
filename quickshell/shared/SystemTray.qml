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

            // display() needs a real parent window plus window-relative
            // coordinates; passing null gives the menu nothing to anchor to.
            function showMenu() {
                const p = trayItem.mapToItem(null, 0, trayItem.height)
                trayItem.modelData.display(trayItem.QsWindow.window, p.x, p.y)
            }

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
                    if (mouse.button === Qt.LeftButton) {
                        if (trayItem.modelData.onlyMenu)
                            trayItem.showMenu()
                        else
                            trayItem.modelData.activate()
                    } else if (trayItem.modelData.hasMenu) {
                        trayItem.showMenu()
                    } else {
                        trayItem.modelData.secondaryActivate()
                    }
                }
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
