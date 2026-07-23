import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            required property SystemTrayItem modelData

            property bool isNetworkApplet: {
                const id = (modelData.id || "").toLowerCase()
                const title = (modelData.title || "").toLowerCase()
                return id.includes("nm-applet") || id.includes("networkmanager") || title.includes("network")
            }

            visible: !isNetworkApplet
            width: visible ? 18 : 0
            height: visible ? 18 : 0

            Component.onCompleted: console.log("[tray-debug]", modelData.id, "|", modelData.title)

            Image {
                anchors.fill: parent
                source: modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: parent.visible
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate()
                    else
                        modelData.secondaryActivate()
                }
                cursorShape: Qt.PointingHandCursor
                enabled: parent.visible
            }
        }
    }
}
