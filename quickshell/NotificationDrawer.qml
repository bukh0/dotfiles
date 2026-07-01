import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PopupWindow {
    id: root

    implicitWidth: 340
    implicitHeight: 540
    color: "transparent"
    visible: NotificationDaemon.isDrawerOpen

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(
            Colors.surfaceContainer.r,
            Colors.surfaceContainer.g,
            Colors.surfaceContainer.b,
            0.97
        )
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notifications"
                    color: Colors.primary
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                }

                Text {
                    text: "Clear All"
                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationDaemon.clearAll()
                        hoverEnabled: true
                        onContainsMouseChanged: parent.color = containsMouse
                            ? Colors.primary
                            : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationDaemon.notifications.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂜"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.3)
                        font.pixelSize: 32
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No notifications"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.3)
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            // Notification list
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationDaemon.notifications.length > 0
                clip: true
                spacing: 8
                model: NotificationDaemon.notifications

                delegate: Rectangle {
                    width: ListView.view.width
                    implicitHeight: notifContent.implicitHeight + 20
                    radius: 10
                    color: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.8)
                    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                    border.width: 1

                    ColumnLayout {
                        id: notifContent
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 12
                        }
                        spacing: 3

                        // App name + dismiss
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: modelData.appName || "App"
                                color: Colors.primary
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "󰅖"
                                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.close) modelData.close()
                                    }
                                }
                            }
                        }

                        // Summary
                        Text {
                            text: modelData.summary || ""
                            color: Colors.surfaceFg
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.family: "JetBrainsMono Nerd Font"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            visible: text !== ""
                        }

                        // Body
                        Text {
                            text: modelData.body || ""
                            color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            visible: text !== ""
                        }
                    }
                }
            }
        }
    }
}
