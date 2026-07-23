import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: root

    property bool isOpen: NotificationDaemon.isDrawerOpen
    property bool windowVisible: false
    visible: windowVisible
    color: "transparent"

    property int fadeOutDuration: 200
    property int drawerY: 44   // was 52 — see ControlPanel.qml for the math

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onIsOpenChanged: {
        if (isOpen) {
            hideTimer.stop()
            windowVisible = true
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: root.fadeOutDuration
        onTriggered: root.windowVisible = false
    }

    onVisibleChanged: {
        if (visible) {
            bgCloser.forceActiveFocus()
        }
    }

    MouseArea {
        id: bgCloser
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        Keys.onEscapePressed: NotificationDaemon.isDrawerOpen = false
        onClicked: NotificationDaemon.isDrawerOpen = false
    }

    Rectangle {
        id: drawerBg
        width: 360
        height: 560

        x: parent.width - width - 10
        y: root.drawerY

        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: root.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    NotificationDaemon.cancelHoverClose()
                    NotificationDaemon.isDrawerOpen = true
                } else {
                    NotificationDaemon.scheduleHoverClose()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

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
                                        NotificationDaemon.closeNotification(index)
                                    }
                                }
                            }
                        }

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
