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

    implicitHeight: 32
    implicitWidth: Math.max(32, label.implicitWidth + (glyph ? 15 : 0)
                           + (glyph && text ? 6 : 0) + leftPadding + rightPadding)
    leftPadding: text ? 11 : 8
    rightPadding: leftPadding
    topPadding: 6
    bottomPadding: 6
    hoverEnabled: true
    font.family: Theme.fontUI
    font.pixelSize: 12
    font.weight: Font.Medium
    opacity: enabled ? 1 : 0.35

    background: Rectangle {
        radius: Theme.notificationItemRadius
        color: Qt.alpha(control.tint, control.down ? 0.22 : control.checked ? 0.17
                        : control.hovered ? 0.12 : control.emphasis ? 0.09 : control.quiet ? 0 : 0.045)
        border.width: 1
        border.color: control.visualFocus ? Colors.primary
                      : Qt.alpha(control.accented ? Colors.primary : Colors.outline,
                                 control.checked ? 0.35 : control.hovered ? 0.3 : control.quiet ? 0 : 0.16)
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
            color: control.accented ? Colors.primary : Qt.alpha(Colors.surfaceFg, 0.85)
            font: control.font
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    ToolTip.visible: hovered && hint !== ""
    ToolTip.text: hint
    ToolTip.delay: 600
    Accessible.name: text || hint
}
