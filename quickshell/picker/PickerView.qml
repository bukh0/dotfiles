import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."
import "../profiles/default" as Profile
import "../profiles/alt" as AltProfile

Rectangle {
    id: view
    signal dismissed()

    readonly property string home: Quickshell.env("HOME")
    property string bin: home + "/.scripts/theme.switcher"
    readonly property bool dark: Colors.background.r + Colors.background.g + Colors.background.b < 1.5
    readonly property color ink: dark ? "#f5f5f7" : "#1d1d1f"
    readonly property color muted: Qt.alpha(ink, 0.52)
    readonly property color faint: Qt.alpha(ink, 0.045)
    property string activeProfile: "default"
    readonly property string uiFont: activeProfile === "alt" ? AltProfile.Theme.fontUI : Profile.Theme.fontUI
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || view.home + "/.cache") + "/quickshell_current_bar"
        onLoaded: view.activeProfile = text().trim()
    }
    readonly property int rowHeight: 64
    property string page: "Home"
    property string generator: ""
    property var presets: []
    property var walls: []
    property var filtered: []
    property int selected: 0
    property var thumbnails: ({})
    signal thumbnailReady(string path)
    property bool busy: false
    property string error: ""
    property string operation: ""
    readonly property bool loading: page === "Wallpapers" ? wallProc.running : page === "Themes" && themeProc.running
    readonly property string current: filtered.length ? filtered[Math.max(0, Math.min(selected, filtered.length - 1))] : ""
    readonly property int columns: 4
    readonly property int pageSize: page === "Wallpapers" ? columns * Math.max(1, Math.floor(grid.height / Math.max(1, grid.cellHeight))) : Math.max(1, Math.floor(themeList.height / rowHeight))

    color: Qt.alpha(dark ? "#242426" : "#f2f2f7", 0.994)
    radius: 22
    border.width: 1
    border.color: Qt.alpha(ink, 0.12)
    // Consume clicks in the panel's padding as well as on its controls.
    MouseArea { anchors.fill: parent }

    function focusSearch() { search.forceActiveFocus() }
    function baseName(path) { return path.substring(path.lastIndexOf("/") + 1) }
    function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/") }
    function thumbUrl(path) { return thumbnails[path] ? fileUrl(thumbnails[path]) : "" }
    function dismiss() { if (!busy) dismissed() }
    function rebuild() {
        gridScroll.stop()
        listScroll.stop()
        const previous = current
        const words = search.text.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean)
        const source = page === "Home" ? ["Wallpaper", "Theme"] : page === "Wallpapers" ? walls : presets
        filtered = source.filter(p => words.every(word => baseName(p).toLocaleLowerCase().includes(word)))
        const index = filtered.indexOf(previous)
        selected = index < 0 ? 0 : index
        Qt.callLater(() => reveal(false))
    }
    function reveal(animate) {
        if (!filtered.length) return
        if (page === "Wallpapers") {
            const row = Math.floor(selected / columns)
            gridScroll.reveal(row * grid.cellHeight, (row + 1) * grid.cellHeight, animate)
        } else {
            listScroll.reveal(selected * rowHeight, (selected + 1) * rowHeight, animate)
        }
    }
    function move(delta) {
        if (busy || !filtered.length) return
        selected = (selected + delta % filtered.length + filtered.length) % filtered.length
        reveal(true)
    }
    function switchPage(next) {
        if (busy || page === next) return
        filtered = []
        page = next
        search.clear()
        selected = 0
        rebuild()
        refresh()
        focusSearch()
    }
    function back() {
        if (busy) return
        if (page === "Home") { dismiss(); return }
        const next = page === "Wallpapers" && generator ? "Themes" : "Home"
        generator = ""
        switchPage(next)
    }
    Component.onCompleted: rebuild()
    function refresh() {
        if (busy) return
        error = ""
        if (page === "Wallpapers") {
            if (!wallProc.running) wallProc.running = true
            if (!thumbProc.running) thumbProc.running = true
        } else if (page === "Themes" && !themeProc.running) themeProc.running = true
        focusSearch()
    }
    function choose() {
        if (!current || busy) return
        if (page === "Home") {
            generator = ""
            switchPage(current === "Wallpaper" ? "Wallpapers" : "Themes")
        } else if (page === "Themes" && (current === "Matugen" || current === "pywal")) {
            generator = current
            switchPage("Wallpapers")
        } else if (page === "Wallpapers") {
            if (generator) apply(generator, current)
            else setWallpaperOnly()
        } else apply(current, "")
    }
    function setWallpaperOnly() {
        if (!current || busy) return
        error = ""
        operation = "Setting wallpaper · " + baseName(current) + "…"
        busy = true
        wallpaperProc._started = false
        wallpaperProc.command = ["swww", "img", current, "--transition-type", "center", "--transition-fps", "60", "--transition-duration", "0.8"]
        launchCheck.process = wallpaperProc
        wallpaperProc.running = true
        launchCheck.restart()
    }
    function apply(theme, wall) {
        if (busy) return
        error = ""
        operation = "Applying " + theme + (wall ? " · " + baseName(wall) : "") + "…"
        busy = true
        applyProc._exited = false
        applyProc.stderrDone = false
        applyProc._started = false
        applyProc.errorText = ""
        applyProc.command = wall ? [bin, "--apply", theme, wall] : [bin, "--apply", theme]
        launchCheck.process = applyProc
        applyProc.running = true
        launchCheck.restart()
    }
    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const nav = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) !== 0
        const step = page === "Wallpapers" ? columns : 1
        if (ctrl && event.key === Qt.Key_C && !search.selectedText) dismiss()
        else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_BracketLeft)) back()
        else if (busy) { event.accepted = true; return }
        else if (event.key === Qt.Key_Down || (nav && event.key === Qt.Key_J)) move(step)
        else if (event.key === Qt.Key_Up || (nav && event.key === Qt.Key_K)) move(-step)
        else if ((nav && event.key === Qt.Key_H) || (event.key === Qt.Key_Left && !search.text)) move(-1)
        else if ((nav && event.key === Qt.Key_L) || (event.key === Qt.Key_Right && !search.text)) move(1)
        else if (event.key === Qt.Key_PageDown || (ctrl && event.key === Qt.Key_D)) move(pageSize)
        else if (event.key === Qt.Key_PageUp || (ctrl && event.key === Qt.Key_U)) move(-pageSize)
        else if (ctrl && event.key === Qt.Key_Home) { selected = 0; reveal(true) }
        else if (ctrl && event.key === Qt.Key_End) { selected = Math.max(0, filtered.length - 1); reveal(true) }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) choose()
        else if (event.key === Qt.Key_F5) refresh()
        else return
        event.accepted = true
    }
    Keys.onPressed: event => handleKey(event)

    Process {
        id: themeProc
        running: false
        command: [view.bin, "--list-themes"]
        stdout: StdioCollector {
            onStreamFinished: { view.presets = text.split("\n").filter(Boolean); view.rebuild() }
        }
        onExited: (code, status) => { if (code !== 0 || status !== 0) view.error = "Could not load themes. Press F5 to retry." }
    }
    Process {
        id: wallProc
        running: false
        command: [view.bin, "--list-walls"]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = [], thumbs = Object.create(null)
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 0) continue
                    const path = line.slice(0, tab)
                    paths.push(path)
                    thumbs[path] = line.slice(tab + 1)
                }
                view.thumbnails = thumbs
                view.walls = paths
                view.rebuild()
            }
        }
        onExited: (code, status) => { if (code !== 0 || status !== 0) view.error = "Could not load wallpapers. Press F5 to retry." }
    }
    Process {
        id: wallpaperProc
        property bool _started: false
        command: ["swww", "img", ""]
        onStarted: _started = true
        onExited: (code, status) => {
            launchCheck.stop()
            view.busy = false
            if (code === 0 && status === 0) view.dismissed()
            else { view.error = "Could not set the wallpaper. Check that swww is running."; view.focusSearch() }
        }
    }
    Process {
        id: thumbProc
        running: false
        command: [view.bin, "--thumbs"]
        stdout: SplitParser { onRead: path => view.thumbnailReady(path) }
        onExited: (code, status) => {
            if (code !== 0 || status !== 0) view.error = "Some previews could not be generated. Press F5 to retry."
        }
    }
    function finishApply() {
        if (!busy || !applyProc._exited || !applyProc.stderrDone) return
        launchCheck.stop()
        busy = false
        if (applyProc.exitCode === 0) dismissed()
        else {
            error = applyProc.errorText.trim().slice(-1200) || "Could not apply the theme. Check the theme engine and try again."
            focusSearch()
        }
    }
    Process {
        id: applyProc
        property bool _exited: false
        property bool stderrDone: false
        property bool _started: false
        property int exitCode: -1
        property string errorText: ""
        onStarted: _started = true
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                applyProc.errorText = text
                applyProc.stderrDone = true
                view.finishApply()
            }
        }
        onExited: (code, status) => {
            exitCode = status === 0 ? code : -1
            _exited = true
            view.finishApply()
        }
    }
    // Failed-to-start does not emit exited on every Quickshell version.
    Timer {
        id: launchCheck
        property var process: applyProc
        interval: 500
        onTriggered: {
            if (view.busy && !process._started && !process.running) {
                view.busy = false
                view.error = "Could not start " + process.command[0]
                view.focusSearch()
            }
        }
    }

    // Document-style scrolling: wheel and touchpad deltas move the content
    // immediately. Only keyboard navigation uses a short animated reveal.
    component Scroller: Item {
        id: sc
        required property Flickable flick
        property real target: 0
        property real rate: 32
        readonly property bool animating: anim.running || inputIdle.running || flick.moving

        function limit(y) {
            return Math.max(flick.originY, Math.min(flick.originY + Math.max(0, flick.contentHeight - flick.height), y))
        }
        function stop() { anim.running = false; inputIdle.stop(); target = flick.contentY }
        function jump(y) {
            stop()
            flick.cancelFlick()
            flick.contentY = limit(y)
            target = flick.contentY
        }
        function wheel(event) {
            let delta
            if (event.pixelDelta.y !== 0) {
                // Preserve high-resolution gestures and their native momentum.
                delta = -event.pixelDelta.y * 3
            } else if (event.angleDelta.y !== 0) {
                // Linear travel, including fractional deltas from Wayland touchpads.
                delta = -event.angleDelta.y / 120 * flick.height * 0.45
            } else return false
            jump(flick.contentY + delta)
            inputIdle.restart()
            return true
        }
        Timer { id: inputIdle; interval: 120 }
        function reveal(top, bottom, animate) {
            const cur = anim.running ? target : flick.contentY
            let y
            if (top < cur) y = top
            else if (bottom > cur + flick.height) y = bottom - flick.height
            else return
            if (animate) {
                rate = 32
                target = limit(y)
                anim.running = true
            } else jump(y)
        }
        FrameAnimation {
            id: anim
            onTriggered: {
                const dist = sc.target - sc.flick.contentY
                if (Math.abs(dist) < 1) {
                    sc.flick.contentY = sc.target
                    running = false
                    return
                }
                let stepBy = dist * (1 - Math.exp(-frameTime * sc.rate))
                if (Math.abs(stepBy) < 1) stepBy = dist > 0 ? 1 : -1
                sc.flick.contentY = Math.round(sc.flick.contentY + stepBy)
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool active: false
        signal clicked()
        implicitHeight: 30
        implicitWidth: chipLabel.implicitWidth + 22
        radius: 8
        color: chipMouse.containsMouse ? view.faint : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.text
            color: Colors.primary
            font.family: view.uiFont
            font.pixelSize: 14
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: !view.busy
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Item {
            Layout.fillWidth: true
            implicitHeight: 34
            Chip {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: view.page !== "Home"
                text: "‹ Back"
                onClicked: view.back()
            }
            Text {
                anchors.centerIn: parent
                text: view.page === "Home" ? "Appearance" : view.page === "Themes" ? "Themes" : view.generator || "Wallpaper"
                color: view.ink
                font.family: view.uiFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Chip {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                onClicked: view.dismiss()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextField {
                id: search
                objectName: "pickerSearch"
                Layout.fillWidth: true
                implicitHeight: 38
                leftPadding: 36
                rightPadding: 14
                enabled: !view.busy
                selectByMouse: true
                font.family: view.uiFont
                font.pixelSize: 14
                color: view.ink
                selectionColor: Colors.primary
                selectedTextColor: Colors.primaryFg
                // Hint drawn outside TextInput so it never scrolls with the text.
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: search.leftPadding
                    anchors.rightMargin: search.rightPadding
                    visible: search.text.length === 0
                    text: view.page === "Home" ? "Search appearance" : view.page === "Wallpapers" ? (view.generator ? "Wallpaper for " + view.generator : "Search wallpapers") : "Search themes"
                    font: search.font
                    color: view.muted
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 9
                    color: Qt.alpha(view.ink, view.dark ? 0.065 : 0.055)
                    // Draw the search symbol without depending on an icon font.
                    Rectangle {
                        x: 13; y: 11; width: 11; height: 11
                        radius: 6; color: "transparent"
                        border.width: 1.5; border.color: view.muted
                        Rectangle {
                            x: 8; y: 9; width: 6; height: 1.5
                            rotation: 45; color: view.muted
                        }
                    }
                }
                onTextChanged: view.rebuild()
                Keys.onPressed: event => view.handleKey(event)
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Scroller { id: gridScroll; flick: grid }
            Scroller { id: listScroll; flick: themeList }

            GridView {
                id: grid
                objectName: "wallpaperGrid"
                anchors.fill: parent
                visible: view.page === "Wallpapers"
                enabled: !view.busy
                clip: true
                model: visible ? view.filtered : []
                // Whole-pixel cells: fractional geometry shimmers while moving.
                cellWidth: Math.floor(width / view.columns)
                cellHeight: Math.round(cellWidth * 9 / 16) + 28
                boundsBehavior: Flickable.StopAtBounds
                pixelAligned: false
                cacheBuffer: cellHeight * 6
                onMovementStarted: gridScroll.stop()

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => { event.accepted = gridScroll.wheel(event) }
                }
                ScrollBar.vertical: ScrollBar {
                    width: hovered || pressed ? 8 : 4
                    policy: ScrollBar.AsNeeded
                    onPressedChanged: { if (pressed) gridScroll.stop() }
                }

                delegate: Item {
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property bool chosen: view.selected === index
                    property int retry: 0
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 12
                        color: tile.chosen ? Qt.alpha(view.ink, 0.08) : tileMouse.containsMouse ? Qt.alpha(view.ink, 0.04) : "transparent"
                        border.width: tile.chosen ? 1 : 0
                        border.color: Colors.primary

                        Image {
                            id: img
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.bottomMargin: 28
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(320, 180)
                            // Versioned URLs keep the cache while retrying new thumbnails safely.
                            source: view.thumbUrl(tile.modelData) + (tile.retry > 0 ? "?retry=" + tile.retry : "")
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            text: view.baseName(tile.modelData)
                            textFormat: Text.PlainText
                            font.family: view.uiFont
                            font.pixelSize: 11
                            color: view.ink
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                        Connections {
                            target: view
                            function onThumbnailReady(path) {
                                if (path === view.thumbnails[tile.modelData]) tile.retry++
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            id: tileMouse
                            onClicked: { view.selected = tile.index; view.choose() }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: themeList
                visible: view.page !== "Wallpapers"
                radius: 12
                color: view.faint
            }
            ListView {
                id: themeList
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                visible: view.page !== "Wallpapers"
                enabled: !view.busy
                clip: true
                model: visible ? view.filtered : []
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                pixelAligned: false
                onMovementStarted: listScroll.stop()

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => { event.accepted = listScroll.wheel(event) }
                }
                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    onPressedChanged: { if (pressed) listScroll.stop() }
                }

                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property bool generated: view.page === "Themes" && (modelData === "Matugen" || modelData === "pywal")
                    width: themeList.width
                    height: view.rowHeight
                    radius: 10
                    color: view.selected === index ? Qt.alpha(view.ink, 0.08) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        Rectangle {
                            width: 34; height: 34; radius: 8
                            color: Qt.alpha(Colors.primary, 0.13)
                            Text {
                                anchors.centerIn: parent
                                text: view.page === "Home" ? (row.modelData === "Wallpaper" ? "▧" : "◐") : row.generated ? "◈" : "◐"
                                font.family: view.uiFont
                                font.pixelSize: 22
                                color: Colors.primary
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData
                                textFormat: Text.PlainText
                                color: view.ink
                                font.family: view.uiFont
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: view.page === "Home" ? (row.modelData === "Wallpaper" ? "Choose your background" : "Personalise your colours") : row.generated ? "Create colours from a wallpaper" : "Apply colour preset"
                                color: view.muted
                                font.family: view.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            text: "›"
                            color: view.muted
                            font.family: view.uiFont
                            font.pixelSize: 24
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 62
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        visible: row.index < view.filtered.length - 1
                        color: Qt.alpha(view.ink, 0.065)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: { if (!listScroll.animating) view.selected = row.index }
                        onClicked: { view.selected = row.index; view.choose() }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                visible: view.filtered.length === 0
                text: view.loading ? "Loading…"
                    : search.text ? "No matches. Try another search."
                    : view.page === "Wallpapers" ? "No wallpapers in ~/Pictures/Wallpapers\nAdd JPG, PNG or WebP images, then press F5."
                    : view.page === "Home" ? "No matches. Try another search." : "No themes found. Press F5 to retry."
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: view.muted
                font.family: view.uiFont
                font.pixelSize: 12
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.maximumHeight: 64
            visible: view.error !== ""
            text: view.error
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 3
            color: Colors.error
            font.family: view.uiFont
            font.pixelSize: 11
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: view.busy ? view.operation
                    : thumbProc.running ? "Preparing previews…"
                    : view.page === "Home" ? "Make it yours" : view.baseName(view.current)
                textFormat: Text.PlainText
                color: view.busy ? Colors.primary : view.muted
                font.family: view.uiFont
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
            Text {
                text: view.page === "Home" ? "↵ Select" : "Esc Back · " + view.filtered.length + (view.page === "Wallpapers" ? " wallpapers" : " themes")
                color: view.muted
                font.family: view.uiFont
                font.pixelSize: 11
            }
        }
    }
}
