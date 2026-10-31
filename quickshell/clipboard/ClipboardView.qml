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
    property bool _rebuilding: false
    property bool confirmClear: false
    readonly property var current: filtered.length ? filtered[Math.min(selected, filtered.length - 1)] : null
    readonly property bool compact: width < 720
    readonly property color muted: Qt.alpha(Colors.surfaceFg, 0.55)
    color: Colors.surface
    radius: 16
    border.color: Qt.alpha(Colors.outline, 0.22)
    border.width: 1
    clip: true

    // Padding and labels belong to the panel, not the outside-click surface.
    MouseArea { anchors.fill: parent }

    function focusSearch() { search.forceActiveFocus() }
    function rebuild(preserveSelection = true) {
        const oldId = preserveSelection && current ? current.id : ""
        const words = search.text.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean)
        const next = service.entries.filter(entry => {
            const match = category === "all" || (category === "text" && (entry.kind === "text" || entry.kind === "link")) || entry.kind === category
            return match && words.every(word => entry.label.toLocaleLowerCase().includes(word))
        })
        const found = oldId ? next.findIndex(entry => entry.id === oldId) : -1
        // Publish the list and selection together before requesting a preview.
        _rebuilding = true
        filtered = next
        selected = preserveSelection
            ? (found >= 0 ? found : Math.min(selected, Math.max(0, filtered.length - 1)))
            : 0
        _rebuilding = false
        service.inspect(current ? current.id : "")
        Qt.callLater(() => { if (filtered.length) history.positionViewAtIndex(selected, ListView.Contain) })
    }
    function move(amount) {
        if (!filtered.length) return
        selected = Math.max(0, Math.min(filtered.length - 1, selected + amount))
        history.positionViewAtIndex(selected, ListView.Contain)
    }
    function choose(paste) { if (current && !confirmClear) service.choose(current.id, paste) }
    function kindName(kind) { return ({text: "Text", image: "Image", link: "Link", file: "File"})[kind] || "Text" }
    function kindIcon(kind) { return ({text: "≡", image: "▧", link: "↗", file: "▤"})[kind] || "≡" }
    function bytes(value) { return value >= 1048576 ? (value / 1048576).toFixed(1) + " MB" : value >= 1024 ? (value / 1024).toFixed(1) + " KB" : value + " bytes" }
    onCategoryChanged: rebuild(false)
    onCurrentChanged: if (!_rebuilding) service.inspect(current ? current.id : "")
    Component.onCompleted: { rebuild(); focusSearch() }
    Connections {
        target: view.service
        function onEntriesChanged() { view.rebuild() }
    }

    component Action: Button {
        id: button
        property bool primary: false
        property bool danger: false
        property bool active: false
        property bool quiet: false
        property string tip: ""
        implicitHeight: 32
        implicitWidth: label.implicitWidth + 24
        focusPolicy: Qt.NoFocus
        hoverEnabled: true
        opacity: enabled ? 1 : 0.35
        background: Rectangle {
            radius: 7
            color: button.primary ? Colors.primary : button.active ? Qt.alpha(Colors.primary, 0.12) : button.hovered ? Qt.alpha(button.danger ? Colors.error : button.active ? Colors.primary : Colors.surfaceFg, 0.08) : button.quiet ? "transparent" : Qt.alpha(Colors.surfaceFg, 0.035)
            border.width: button.primary || button.quiet ? 0 : 1
            border.color: Qt.alpha(button.danger ? Colors.error : Colors.outline, button.hovered ? 0.5 : 0.18)
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: Text {
            id: label
            text: button.text
            color: button.primary ? Colors.primaryFg : button.danger ? Colors.error : button.active ? Colors.primary : Colors.surfaceFg
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
        anchors.margins: 22
        spacing: 14
        RowLayout {
            spacing: 12
            ColumnLayout {
                spacing: 4
                Text { text: "Clipboard"; color: Colors.surfaceFg; font.pixelSize: 21; font.weight: Font.DemiBold; font.family: "sans-serif" }
                Text { text: "Your recent copies, ready to use"; color: view.muted; font.family: "sans-serif"; font.pixelSize: 12; visible: view.width > 470 }
            }
            Item { Layout.fillWidth: true }
            Action { text: "Refresh"; quiet: true; tip: "Refresh history · Ctrl+R"; enabled: !service.loading; onClicked: service.refresh() }
            Action { text: "×"; quiet: true; tip: "Close · Esc"; onClicked: view.dismissed() }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 9
            color: Colors.surfaceContainer
            border.width: 1
            border.color: search.activeFocus ? Qt.alpha(Colors.primary, 0.4) : Qt.alpha(Colors.outline, 0.3)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 12
                spacing: 12
                Item {
                    implicitWidth: 16; implicitHeight: 18
                    Rectangle { x: 1; y: 1; width: 11; height: 11; radius: 6; color: "transparent"; border.width: 1.5; border.color: view.muted }
                    Rectangle { x: 11; y: 11; width: 6; height: 1.5; rotation: 45; transformOrigin: Item.Left; color: view.muted }
                }
                TextField {
                    id: search
                    objectName: "clipboardSearch"
                    readOnly: view.confirmClear
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 0
                    background: null
                    color: Colors.surfaceFg
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.primaryFg
                    placeholderText: "Search your clipboard…"
                    placeholderTextColor: view.muted
                    font.pixelSize: 13
                    font.family: "sans-serif"
                    selectByMouse: true
                    onTextChanged: view.rebuild(false)
                    Keys.onPressed: event => {
                        const ctrl = Boolean(event.modifiers & Qt.ControlModifier)
                        if (event.key === Qt.Key_Escape) {
                            if (view.confirmClear) view.confirmClear = false
                            else if (text) text = ""
                            else view.dismissed()
                        } else if (view.confirmClear) { event.accepted = true; return }
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
                model: [{key: "all", title: "All"}, {key: "text", title: "Text & links"}, {key: "image", title: "Images"}]
                Action {
                    required property var modelData
                    text: modelData.title
                    active: view.category === modelData.key
                    quiet: true
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
            spacing: 18
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                radius: 10
                border.width: 0
                ListView {
                id: history
                objectName: "clipboardHistory"
                    anchors.fill: parent
                    anchors.margins: 0
                    clip: true
                    spacing: 4
                    model: view.filtered
                    boundsBehavior: Flickable.StopAtBounds
                    // Move three entries per wheel notch instead of Qt's small
                    // text-oriented default, with the same sensitivity for touchpads.
                    readonly property real wheelStep: 3 * (68 + spacing)
                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const ticks = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 15
                            const delta = ticks * history.wheelStep
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
                        radius: 8
                        color: chosen ? Qt.alpha(Colors.primary, 0.10) : mouse.containsMouse ? Qt.alpha(Colors.surfaceFg, 0.04) : "transparent"
                        border.width: 1
                        border.color: chosen ? Qt.alpha(Colors.primary, 0.22) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 11
                            Rectangle {
                                implicitWidth: 32; implicitHeight: 36; radius: 6
                                color: Qt.alpha(Colors.surfaceFg, 0.045)
                                Text { anchors.centerIn: parent; text: ({text: "Aa", image: "IMG", link: "URL", file: "FILE"})[row.modelData.kind] || "Aa"; color: row.chosen ? Colors.primary : view.muted; font.family: "sans-serif"; font.pixelSize: row.modelData.kind === "text" ? 13 : 8; font.weight: Font.Medium }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.label.replace(/\s+/g, " ").trim()
                                    textFormat: Text.PlainText
                                    color: Colors.surfaceFg
                                    font.pixelSize: 13
                                    font.family: "sans-serif"
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                Text { text: view.kindName(row.modelData.kind) + (row.index === 0 && !search.text && view.category === "all" ? "  ·  Most recent" : ""); color: view.muted; font.pixelSize: 10 }
                            }
                            Text { text: "↵"; color: view.muted; font.pixelSize: 16; visible: row.chosen }
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
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: search.text ? "⌕" : "▤"; color: Qt.alpha(Colors.primary, 0.4); font.pixelSize: 38 }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: service.loading ? "Loading your clipboard…" : search.text ? "No matching entries" : "Nothing here yet"; color: Colors.surfaceFg; font.pixelSize: 14 }
                    Text { width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; text: search.text ? "Try a different word or another filter." : "Copy some text or an image to get started."; color: view.muted; font.pixelSize: 11 }
                }
            }

            Rectangle {
                Layout.preferredWidth: view.width * 0.40
                Layout.fillHeight: true
                visible: !view.compact
                color: Colors.surfaceContainer
                radius: 10
                border.color: Qt.alpha(Colors.outline, 0.10)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 17
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Preview"; font.family: "sans-serif"; font.pixelSize: 12; font.weight: Font.Medium; color: view.muted }
                        Item { Layout.fillWidth: true }
                        Text { text: view.current ? view.kindName(view.current.kind) : ""; color: view.muted; font.pixelSize: 11 }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(Colors.outline, 0.15) }
                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Image {
                            anchors.fill: parent
                            source: service.preview.image || ""
                            visible: Boolean(service.preview.image)
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
                                font.family: "sans-serif"
                                font.pixelSize: 13
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

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(Colors.outline, 0.14) }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Action { text: "Clear history"; quiet: true; danger: true; enabled: service.entries.length > 0 && !service.busy; onClicked: view.confirmClear = true }
            Action { text: "Delete"; quiet: true; tip: "Delete selected entry · Ctrl+Delete"; enabled: Boolean(view.current) && !service.busy; onClicked: service.perform("delete", view.current.id) }
            Item { Layout.fillWidth: true }
            Action { text: "Copy"; tip: "Copy and close · Ctrl+Enter"; enabled: Boolean(view.current) && !service.busy; onClicked: view.choose(false) }
            Action { text: service.busy ? "Working…" : "Paste  ↵"; primary: true; tip: "Paste into the previous app · Enter"; enabled: Boolean(view.current) && !service.busy; onClicked: view.choose(true) }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: view.height >= 540
            text: "↑ ↓  Navigate     ·     Tab  Filter     ·     Enter  Paste     ·     Ctrl+Enter  Copy"
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
