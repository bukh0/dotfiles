import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: view
    required property var service
    signal dismissed()
    property string category: "all"
    property var filtered: []
    property int selected: 0
    property bool confirmClear: false
    readonly property var current: filtered.length ? filtered[Math.min(selected, filtered.length - 1)] : null
    readonly property bool compact: width < 720
    readonly property color muted: Qt.alpha(Colors.surfaceFg, 0.55)
    color: Colors.surface
    radius: 22
    border.color: Qt.alpha(Colors.outline, 0.45)
    border.width: 1
    clip: true

    function focusSearch() { search.forceActiveFocus() }
    function rebuild() {
        const oldId = current ? current.id : ""
        const words = search.text.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean)
        filtered = service.entries.filter(entry => {
            const match = category === "all" || (category === "text" && (entry.kind === "text" || entry.kind === "link")) || entry.kind === category
            return match && words.every(word => entry.label.toLocaleLowerCase().includes(word))
        })
        const found = filtered.findIndex(entry => entry.id === oldId)
        selected = found >= 0 ? found : Math.min(selected, Math.max(0, filtered.length - 1))
        Qt.callLater(() => history.positionViewAtIndex(selected, ListView.Contain))
    }
    function move(amount) {
        selected = Math.max(0, Math.min(filtered.length - 1, selected + amount))
        history.positionViewAtIndex(selected, ListView.Contain)
    }
    function choose(paste) { if (current && !confirmClear) service.choose(current.id, paste) }
    function kindName(kind) { return ({text: "Text", image: "Image", link: "Link", file: "File"})[kind] || "Text" }
    function kindIcon(kind) { return ({text: "≡", image: "▧", link: "↗", file: "▤"})[kind] || "≡" }
    function bytes(value) { return value >= 1048576 ? (value / 1048576).toFixed(1) + " MB" : value >= 1024 ? (value / 1024).toFixed(1) + " KB" : value + " bytes" }
    onCategoryChanged: { selected = 0; rebuild() }
    onCurrentChanged: service.inspect(current ? current.id : "")
    Component.onCompleted: { rebuild(); focusSearch() }
    Connections {
        target: view.service
        function onEntriesChanged() { view.rebuild() }
    }

    component Action: Button {
        id: button
        property bool primary: false
        property bool danger: false
        property string tip: ""
        implicitHeight: 34
        implicitWidth: label.implicitWidth + 24
        focusPolicy: Qt.NoFocus
        hoverEnabled: true
        opacity: enabled ? 1 : 0.35
        background: Rectangle {
            radius: 9
            color: button.primary ? Colors.primary : button.hovered ? Qt.alpha(button.danger ? Colors.error : Colors.primary, 0.14) : Qt.alpha(Colors.surfaceFg, 0.045)
            border.width: button.primary ? 0 : 1
            border.color: Qt.alpha(button.danger ? Colors.error : Colors.outline, button.hovered ? 0.5 : 0.18)
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: Text {
            id: label
            text: button.text
            color: button.primary ? Colors.primaryFg : button.danger ? Colors.error : Colors.surfaceFg
            font.family: "sans-serif"
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        ToolTip.visible: hovered && tip !== ""
        ToolTip.text: tip
        ToolTip.delay: 600
        Accessible.name: tip || text
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18
        RowLayout {
            spacing: 12
            Rectangle {
                implicitWidth: 44; implicitHeight: 44; radius: 14
                color: Qt.alpha(Colors.primary, 0.13)
                Text { anchors.centerIn: parent; text: "▤"; color: Colors.primary; font.pixelSize: 26 }
            }
            ColumnLayout {
                spacing: 3
                Text { text: "Clipboard"; color: Colors.surfaceFg; font.pixelSize: 23; font.weight: Font.DemiBold; font.family: "sans-serif" }
                Text { text: "A little space for everything you copy."; color: view.muted; font.pixelSize: 11; visible: view.width > 470 }
            }
            Item { Layout.fillWidth: true }
            Action { text: "↻"; tip: "Refresh history · Ctrl+R"; enabled: !service.loading; onClicked: service.refresh() }
            Action { text: "✕"; tip: "Close · Esc"; onClicked: view.dismissed() }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 50
            radius: 13
            color: Colors.surfaceContainer
            border.width: 1
            border.color: search.activeFocus ? Qt.alpha(Colors.primary, 0.65) : Qt.alpha(Colors.outline, 0.3)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 12
                spacing: 12
                Text { text: "⌕"; color: Colors.primary; font.pixelSize: 26 }
                TextField {
                    id: search
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 0
                    background: null
                    color: Colors.surfaceFg
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.primaryFg
                    placeholderText: "Search your clipboard…"
                    placeholderTextColor: view.muted
                    font.pixelSize: 14
                    selectByMouse: true
                    onTextChanged: { view.selected = 0; view.rebuild() }
                    Keys.onPressed: event => {
                        const ctrl = Boolean(event.modifiers & Qt.ControlModifier)
                        if (event.key === Qt.Key_Escape) {
                            if (view.confirmClear) view.confirmClear = false
                            else if (text) text = ""
                            else view.dismissed()
                        } else if (view.confirmClear) { return }
                        else if (event.key === Qt.Key_Down) view.move(1)
                        else if (event.key === Qt.Key_Up) view.move(-1)
                        else if (event.key === Qt.Key_PageDown) view.move(6)
                        else if (event.key === Qt.Key_PageUp) view.move(-6)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) view.choose(!ctrl)
                        else if (ctrl && event.key === Qt.Key_Delete && view.current) service.perform("delete", view.current.id)
                        else if (ctrl && event.key === Qt.Key_R) service.refresh()
                        else if (ctrl && event.key === Qt.Key_L) selectAll()
                        else if (event.key === Qt.Key_Tab) {
                            const tabs = ["all", "text", "image"]
                            view.category = tabs[(tabs.indexOf(view.category) + 1) % 3]
                        } else if (event.key === Qt.Key_Backtab) {
                            const tabs = ["all", "text", "image"]
                            view.category = tabs[(tabs.indexOf(view.category) + 2) % 3]
                        } else { return }
                        event.accepted = true
                    }
                }
                Text { text: "ESC"; font.pixelSize: 9; font.letterSpacing: 1; color: view.muted }
            }
        }

        RowLayout {
            spacing: 6
            Repeater {
                model: [{key: "all", title: "Everything"}, {key: "text", title: "Text & links"}, {key: "image", title: "Images"}]
                Action {
                    required property var modelData
                    text: modelData.title
                    primary: view.category === modelData.key
                    onClicked: { view.category = modelData.key; view.focusSearch() }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: service.loading ? "Refreshing…" : view.filtered.length + (view.filtered.length === 1 ? " item" : " items")
                color: view.muted; font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.surfaceContainer
                radius: 14
                border.color: Qt.alpha(Colors.outline, 0.12)
                ListView {
                id: history
                objectName: "clipboardHistory"
                    anchors.fill: parent
                    anchors.margins: 7
                    clip: true
                    spacing: 5
                    model: view.filtered
                    boundsBehavior: Flickable.StopAtBounds
                    // Move three entries per wheel notch instead of Qt's small
                    // text-oriented default. Preserve precise touchpad deltas.
                    readonly property real wheelStep: 3 * (68 + spacing)
                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const delta = event.pixelDelta.y !== 0
                                ? event.pixelDelta.y
                                : event.angleDelta.y / 120 * history.wheelStep
                            if (delta === 0) { event.accepted = false; return }
                            history.cancelFlick()
                            const start = history.originY
                            const end = start + Math.max(0, history.contentHeight - history.height)
                            history.contentY = Math.max(start, Math.min(end, history.contentY - delta))
                            event.accepted = true
                        }
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool chosen: view.selected === index
                        width: history.width
                        height: 68
                        radius: 10
                        color: chosen ? Qt.alpha(Colors.primary, 0.13) : mouse.containsMouse ? Qt.alpha(Colors.surfaceFg, 0.04) : "transparent"
                        border.width: 1
                        border.color: chosen ? Qt.alpha(Colors.primary, 0.38) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 11
                            Rectangle {
                                implicitWidth: 34; implicitHeight: 34; radius: 9
                                color: Qt.alpha(row.modelData.kind === "image" ? Colors.secondary : Colors.primary, 0.1)
                                Text { anchors.centerIn: parent; text: view.kindIcon(row.modelData.kind); color: row.modelData.kind === "image" ? Colors.secondary : Colors.primary; font.pixelSize: 21 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.label
                                    textFormat: Text.PlainText
                                    color: Colors.surfaceFg
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                Text { text: view.kindName(row.modelData.kind) + (row.index === 0 && !search.text && view.category === "all" ? "  ·  Most recent" : ""); color: view.muted; font.pixelSize: 10 }
                            }
                            Text { text: "↵"; color: Colors.primary; font.pixelSize: 17; visible: row.chosen }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { view.selected = row.index; view.focusSearch() }
                            onDoubleClicked: { view.selected = row.index; view.choose(true) }
                        }
                        Accessible.role: Accessible.ListItem
                        Accessible.name: row.modelData.label
                        Accessible.selected: chosen
                    }
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 10
                    visible: !view.filtered.length
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: search.text ? "⌕" : "▤"; color: Qt.alpha(Colors.primary, 0.65); font.pixelSize: 38 }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: service.loading ? "Loading your clipboard…" : search.text ? "No matching entries" : "Nothing here yet"; color: Colors.surfaceFg; font.pixelSize: 14 }
                    Text { width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; text: search.text ? "Try a different word or another filter." : "Copy some text or an image to get started."; color: view.muted; font.pixelSize: 11 }
                }
            }

            Rectangle {
                Layout.preferredWidth: view.width * 0.38
                Layout.fillHeight: true
                visible: !view.compact
                color: Colors.surfaceContainer
                radius: 14
                border.color: Qt.alpha(Colors.outline, 0.12)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 17
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "PREVIEW"; font.pixelSize: 9; font.letterSpacing: 1.7; color: view.muted }
                        Item { Layout.fillWidth: true }
                        Text { text: view.current ? view.kindName(view.current.kind) : ""; color: Colors.tertiary; font.pixelSize: 10 }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(Colors.outline, 0.15) }
                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Image {
                            anchors.fill: parent
                            source: service.preview.image || ""
                            visible: source !== ""
                            asynchronous: true
                            sourceSize.width: 900
                            sourceSize.height: 900
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            autoTransform: true
                        }
                        ScrollView {
                            anchors.fill: parent
                            visible: !service.preview.image
                            clip: true
                            contentWidth: availableWidth
                            TextArea {
                                readOnly: true
                                selectByMouse: true
                                activeFocusOnPress: false
                                text: !view.current ? "Select an entry to take a closer look." : service.previewLoading ? "Loading preview…" : service.preview.error || service.preview.text || ""
                                textFormat: TextEdit.PlainText
                                wrapMode: TextEdit.WrapAnywhere
                                color: service.preview.error ? Colors.error : Colors.surfaceFg
                                font.family: "monospace"
                                font.pixelSize: 12
                                background: null
                                padding: 0
                            }
                        }
                    }
                    Text { visible: Boolean(service.preview.size); text: view.bytes(service.preview.size || 0); color: view.muted; font.pixelSize: 10 }
                }
            }
        }

        Rectangle {
            visible: service.error !== ""
            Layout.fillWidth: true
            implicitHeight: errorText.implicitHeight + 20
            radius: 10
            color: Qt.alpha(Colors.error, 0.1)
            Text { id: errorText; anchors.fill: parent; anchors.margins: 10; text: service.error; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Colors.error; font.pixelSize: 11 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Action { text: "Clear history"; danger: true; enabled: service.entries.length > 0 && !service.busy; onClicked: view.confirmClear = true }
            Action { text: "Delete"; tip: "Delete selected entry · Ctrl+Delete"; enabled: Boolean(view.current) && !service.busy; onClicked: service.perform("delete", view.current.id) }
            Item { Layout.fillWidth: true }
            Action { text: "Copy"; tip: "Copy and close · Ctrl+Enter"; enabled: Boolean(view.current) && !service.busy; onClicked: view.choose(false) }
            Action { text: service.busy ? "Working…" : "Paste  ↵"; primary: true; tip: "Paste into the previous app · Enter"; enabled: Boolean(view.current) && !service.busy; onClicked: view.choose(true) }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: view.height >= 540
            text: "↑ ↓  Navigate     ·     Tab  Filter     ·     Ctrl+Enter  Copy     ·     Esc  Close"
            color: view.muted
            font.pixelSize: 10
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: view.radius
        visible: view.confirmClear
        color: Qt.alpha(Colors.background, 0.88)
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 390)
            height: 204
            radius: 18
            color: Colors.surfaceContainerHigh
            border.color: Qt.alpha(Colors.outline, 0.4)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16
                Text { text: "Clear clipboard history?"; color: Colors.surfaceFg; font.pixelSize: 19; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; text: "All saved entries will be removed. This cannot be undone. Your current clipboard stays available."; wrapMode: Text.WordWrap; color: view.muted; font.pixelSize: 12 }
                RowLayout {
                    Item { Layout.fillWidth: true }
                    Action { text: "Cancel"; onClicked: { view.confirmClear = false; view.focusSearch() } }
                    Action { text: "Clear everything"; danger: true; enabled: !service.busy; onClicked: { view.confirmClear = false; service.perform("wipe", ""); view.focusSearch() } }
                }
            }
        }
    }
}
