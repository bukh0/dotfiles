import QtQuick
import QtQuick.Controls

ToolTip {
    id: control
    // External labels and URLs must never be interpreted as rich text.
    popupType: Popup.Window
    property int textWrapMode: Text.Wrap
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.palette.toolTipText
        textFormat: Text.PlainText
        wrapMode: control.textWrapMode
    }
}
