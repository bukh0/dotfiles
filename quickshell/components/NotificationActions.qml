import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Flow {
    id: root
    property int notificationId: -1
    property var actions: NotificationDaemon.actionsFor(notificationId)
    Layout.fillWidth: true
    spacing: 6
    visible: actions.length > 0
    Repeater {
        model: root.actions
        Button {
            required property var modelData
            required property int index
            text: modelData.text
            width: Math.min(implicitWidth, root.width)
            font.family: Theme.fontUI
            contentItem: Text {
                text: parent.text
                textFormat: Text.PlainText
                color: Colors.surfaceFg
                font: parent.font
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: NotificationDaemon.invokeAction(root.notificationId, index)
        }
    }
}
