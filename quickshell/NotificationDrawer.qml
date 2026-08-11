import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "."

PanelWindow {
    id: root

    // ── Configuration & State ────────────────────────────────
    property bool isOpen: NotificationDaemon.isDrawerOpen
    property int fadeOutDuration: 200
    property int drawerY: 44
    property string uiFont: "sans-serif"
    property string iconFont: "JetBrainsMono Nerd Font"

    // Declarative visibility: Window is visible if commanded open, 
    // OR if it is currently in the middle of fading out.
    visible: isOpen || drawerBg.opacity > 0
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onIsOpenChanged: {
        if (isOpen) {
            bgCloser.forceActiveFocus()
        }
    }

    // ── Background Dismissal ─────────────────────────────────
    MouseArea {
        id: bgCloser
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        // Only intercept clicks when fully open, not when fading out
        enabled: root.isOpen 
        
        Keys.onEscapePressed: (event) => { 
            NotificationDaemon.isDrawerOpen = false 
            event.accepted = true
        }
        onClicked: (mouse) => { 
            NotificationDaemon.isDrawerOpen = false 
        }
    }

    // ── Drawer UI ────────────────────────────────────────────
    Rectangle {
        id: drawerBg
        width: 380 
        height: 560

        x: parent.width - width - 12
        y: root.isOpen ? root.drawerY : root.drawerY - 10 
        
        Behavior on y { 
            NumberAnimation { duration: root.fadeOutDuration; easing.type: Easing.OutCubic } 
        }

        radius: 12
        color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
        border.width: 1

        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on opacity { 
            NumberAnimation { duration: root.fadeOutDuration } 
        }

        // Prevent clicks on the drawer itself from closing the window
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => { mouse.accepted = true }
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

            // ── Header ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notifications"
                    color: Colors.primary
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.family: root.uiFont
                    Layout.fillWidth: true
                }

                Text {
                    text: "Clear All"
                    color: clearHover.hovered ? Colors.primary : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                    font.pixelSize: 12
                    font.family: root.uiFont
                    font.weight: Font.Medium

                    HoverHandler {
                        id: clearHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: NotificationDaemon.clearAll()
                    }
                }
            }

            // ── Empty State ───────────────────────────────────
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
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.2)
                        font.pixelSize: 42
                        font.family: root.iconFont
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No new notifications"
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                        font.pixelSize: 13
                        font.family: root.uiFont
                    }
                }
            }

            // ── Notification List ─────────────────────────────
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationDaemon.notifications.length > 0
                clip: true
                spacing: 10
                model: NotificationDaemon.notifications
                
                // Reserve space for the scrollbar to prevent UI reflow
                rightMargin: ScrollBar.vertical.visible ? 8 : 0
                cacheBuffer: 300 

                // Smooth Animations for list changes
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 250 }
                    NumberAnimation { property: "x"; from: 30; to: 0; duration: 250; easing.type: Easing.OutCubic }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                    NumberAnimation { property: "scale"; to: 0.9; duration: 200 }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutQuad }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 6
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.3)
                    }
                }

                function getIconSource(data) {
                    if (data.image) {
                        const img = data.image.toString();
                        return img.startsWith("/") ? "file://" + img : img;
                    }
                    if (data.appIcon) {
                        const icon = data.appIcon.toString();
                        if (icon.startsWith("/")) return "file://" + icon;
                        return Quickshell.iconPath(icon); 
                    }
                    return "";
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: ListView.view.width - ListView.view.rightMargin
                    implicitHeight: notifContent.implicitHeight + 24
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
                        spacing: 8

                        // --- DELEGATE HEADER ---
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: modelData.appName || "App"
                                color: Colors.primary
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.family: root.uiFont
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.time ? Qt.formatTime(modelData.time, "hh:mm") : ""
                                color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.5)
                                font.pixelSize: 10
                                font.family: root.uiFont
                                Layout.rightMargin: 8
                            }

                            // FIX: Better Close Button with a proper 24x24 Hitbox
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 24
                                height: 24
                                radius: 12
                                color: closeHover.hovered ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.15) : "transparent"
                                
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: closeHover.hovered ? Colors.error : Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.4)
                                    font.pixelSize: 14
                                    font.family: root.iconFont
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                HoverHandler {
                                    id: closeHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                
                                TapHandler {
                                    onTapped: {
                                        NotificationDaemon.closeNotification(index)
                                    }
                                }
                            }
                        }

                        // --- DELEGATE CONTENT ---
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Layout.alignment: Qt.AlignTop

                            // IMAGE PREVIEW
                            Image {
                                source: notifList.getIconSource(modelData)
                                visible: source.toString() !== ""
                                Layout.preferredWidth: 48 
                                Layout.preferredHeight: 48
                                Layout.alignment: Qt.AlignTop
                                fillMode: Image.PreserveAspectFit 
                                clip: true
                                asynchronous: true
                                sourceSize: Qt.size(96, 96) 
                            }

                            // TEXT (Summary + Body)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Layout.alignment: Qt.AlignTop

                                Text {
                                    text: modelData.summary || ""
                                    color: Colors.surfaceFg
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    font.family: root.uiFont
                                    wrapMode: Text.Wrap
                                    
                                    Layout.minimumWidth: 0 
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }

                                Text {
                                    text: modelData.body || ""
                                    textFormat: Text.StyledText 
                                    color: Qt.rgba(Colors.surfaceFg.r, Colors.surfaceFg.g, Colors.surfaceFg.b, 0.7)
                                    font.pixelSize: 12
                                    font.family: root.uiFont
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4 
                                    elide: Text.ElideRight
                                    
                                    Layout.minimumWidth: 0 
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
