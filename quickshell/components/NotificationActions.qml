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
        NotificationButton {
            required property var modelData
            required property int index
            text: modelData.text
            width: Math.min(implicitWidth, root.width)
            emphasis: index === 0
            hint: text
            onClicked: NotificationDaemon.invokeAction(root.notificationId, index)
        }
    }
}
