import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Button {
    id: control
    property string glyph: ""
    property string hint: ""
    property bool emphasis: false
    property bool quiet: false
    readonly property bool accented: checked || emphasis
    readonly property color tint: accented ? Colors.primary : Colors.surfaceFg

    implicitHeight: 30
    // Use the layout's rounded size so fractional font metrics cannot elide
    // a label even when the button is at its natural width.
    implicitWidth: Math.max(30, Math.ceil(implicitContentWidth) + leftPadding + rightPadding)
    leftPadding: text ? 12 : 7
    rightPadding: leftPadding
    topPadding: 5
    bottomPadding: 5
    hoverEnabled: true
    font.family: Theme.fontUI
    font.pixelSize: 12
    font.weight: Font.Medium
    opacity: enabled ? 1 : 0.35

    background: Rectangle {
        radius: height / 2
        color: Qt.alpha(control.tint, control.down ? 0.23 : control.checked ? 0.17
                        : control.hovered ? 0.14 : control.emphasis ? 0.10 : control.quiet ? 0 : 0.04)
        border.width: 1
        border.color: control.visualFocus ? Colors.primary
                      : Qt.alpha(control.accented ? Colors.primary : Colors.outline,
                                 control.checked ? 0.40 : control.hovered ? 0.35
                                 : control.emphasis ? 0.25 : control.quiet ? 0 : 0.22)
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }
    contentItem: RowLayout {
        spacing: 6
        Text {
            visible: control.glyph !== ""
            text: control.glyph
            color: control.accented ? Colors.primary : Qt.alpha(Colors.surfaceFg, 0.75)
            font.family: Theme.fontMono
            font.pixelSize: 14
            Layout.preferredWidth: 15
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            id: label
            visible: control.text !== ""
            text: control.text
            textFormat: Text.PlainText
            color: control.accented ? Colors.primary : Qt.alpha(Colors.surfaceFg, 0.92)
            font: control.font
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }
    }
    HoverHandler { blocking: false; cursorShape: Qt.PointingHandCursor }
    ToolTip {
        id: plainTooltip1
        popupType: Popup.Window
        contentItem: Text {
            text: plainTooltip1.text
            font: plainTooltip1.font
            color: plainTooltip1.palette.toolTipText
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        visible: control.hovered && control.hint !== ""
        text: control.hint
        delay: 600
    }
    Accessible.name: text || hint
}
