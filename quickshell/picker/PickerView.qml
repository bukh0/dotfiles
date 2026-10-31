import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

Rectangle {
    id: view
    signal dismissed()

    readonly property string home: Quickshell.env("HOME")
    property string bin: Quickshell.env("QS_THEME_SWITCHER") || home + "/.scripts/theme.switcher"
    // Shared palette installed by theme.switcher for presets, Matugen and pywal.
    readonly property color panelColor: Colors.surface
    readonly property color fieldColor: Colors.surfaceContainer
    readonly property color accent: Colors.primary
    readonly property color accentText: Colors.primaryFg
    readonly property color errorColor: Colors.error
    readonly property color ink: Colors.surfaceFg
    readonly property color muted: Qt.alpha(Colors.surfaceFg, 0.65)
    readonly property color faint: Qt.alpha(ink, 0.045)
    // Both bar profiles use sans-serif. Avoid loading their complete modules
    // and enumerating every installed font just to obtain this one value.
    readonly property string uiFont: "sans-serif"
    readonly property int rowHeight: 48
    readonly property int preferredHeight: page === "Wallpapers" ? 540
        : Math.max(200, 82 + Math.max(2, Math.min(8, filtered.length)) * rowHeight)
          + (error !== "" ? 64 : 0) + (busy ? 24 : 0)
    property string page: "Home"
    property string generator: ""
    property var presets: []
    property var walls: []
    property var filtered: []
    property int selected: 0
    property var thumbnails: ({})
    property var thumbnailVersions: ({})
    signal thumbnailReady(string path)
    onThumbnailReady: path => {
        // Remember completions even before the listing or delegates exist.
        const versions = Object.assign({}, thumbnailVersions)
        versions[path] = (versions[path] || 0) + 1
        thumbnailVersions = versions
    }
    property bool busy: false
    // The search field loses focus when disabled; keep cancellation keys here.
    onBusyChanged: {
        if (busy) forceActiveFocus()
        else {
            Qt.callLater(wallProc.finish)
            Qt.callLater(themeProc.finish)
            Qt.callLater(thumbProc.finish)
        }
    }
    property int operationTimeoutSeconds: 45
    property bool operationCancelled: false
    function boundedCommand(args) {
        return ["timeout", "--signal=TERM", "--kill-after=2s", String(operationTimeoutSeconds) + "s"].concat(args)
    }
    function cancelOperation() {
        if (!busy || operationCancelled) return
        operationCancelled = true
        operation = "Cancelling…"
        if (launchCheck.process.running) launchCheck.process.signal(15)
    }
    function operationError(code, fallback) {
        if (operationCancelled) return "Operation cancelled. Some changes may already have been applied."
        if (code === 124 || code === 137) return "Operation timed out. Some changes may already have been applied."
        return fallback
    }
    property string error: ""
    property string operation: ""
    readonly property bool loading: page === "Wallpapers" ? wallProc.pending : page === "Themes" && themeProc.pending
    readonly property string current: filtered.length ? filtered[Math.max(0, Math.min(selected, filtered.length - 1))] : ""
    readonly property int columns: 4
    readonly property int pageSize: page === "Wallpapers" ? columns * Math.max(1, Math.floor(grid.height / Math.max(1, grid.cellHeight))) : Math.max(1, Math.floor(themeList.height / rowHeight))

    color: view.panelColor
    radius: 16
    border.width: 1
    border.color: Qt.alpha(view.accent, 0.18)
    // Consume clicks in the panel's padding as well as on its controls.
    MouseArea { anchors.fill: parent }

    function focusSearch() { search.forceActiveFocus() }
    function baseName(path) { return path.substring(path.lastIndexOf("/") + 1) }
    function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/") }
    function thumbUrl(path) {
        const thumbnail = thumbnails[path]
        if (!thumbnail) return ""
        const version = thumbnailVersions[thumbnail] || 0
        return fileUrl(thumbnail) + (version ? "?retry=" + version : "")
    }
    function dismiss() { if (busy) cancelOperation(); else dismissed() }
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
        if (page === "Wallpapers" && delta !== 0 && delta % columns === 0) {
            const column = selected % columns
            const rows = Math.ceil(filtered.length / columns)
            const row = Math.floor(selected / columns)
            const nextRow = ((row + delta / columns) % rows + rows) % rows
            selected = Math.min(filtered.length - 1, nextRow * columns + column)
        } else selected = (selected + delta % filtered.length + filtered.length) % filtered.length
        reveal(true)
    }
    function movePage(deltaPages) {
        if (busy || !filtered.length || deltaPages === 0) return
        if (page === "Wallpapers") {
            const column = selected % columns
            const lastRow = Math.floor((filtered.length - 1) / columns)
            const row = Math.floor(selected / columns)
            const nextRow = Math.max(0, Math.min(lastRow, row + deltaPages * pageSize / columns))
            selected = Math.min(filtered.length - 1, nextRow * columns + column)
        } else selected = Math.max(0, Math.min(filtered.length - 1, selected + deltaPages * pageSize))
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
        if (busy) { cancelOperation(); return }
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
            wallProc.start()
            thumbProc.start()
        } else if (page === "Themes") themeProc.start()
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
        operationCancelled = false
        busy = true
        wallpaperProc._started = false
        wallpaperProc.command = boundedCommand(["swww", "img", current, "--transition-type", "center", "--transition-fps", "60", "--transition-duration", "0.8"])
        launchCheck.process = wallpaperProc
        launchCheck.restart()
        wallpaperProc.running = true
    }
    function apply(theme, wall) {
        if (busy) return
        error = ""
        operation = "Applying " + theme + (wall ? " · " + baseName(wall) : "") + "…"
        operationCancelled = false
        busy = true
        applyProc._exited = false
        applyProc.stderrDone = false
        applyProc._started = false
        applyProc.errorText = ""
        applyProc.command = boundedCommand(wall ? [bin, "--apply", theme, wall] : [bin, "--apply", theme])
        launchCheck.process = applyProc
        launchCheck.restart()
        applyProc.running = true
    }
    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const nav = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) !== 0
        const step = page === "Wallpapers" ? columns : 1
        if (ctrl && event.key === Qt.Key_C && (busy || !search.selectedText)) dismiss()
        else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_BracketLeft)) back()
        else if (busy) { event.accepted = true; return }
        else if (event.key === Qt.Key_Down || (nav && event.key === Qt.Key_J)) move(step)
        else if (event.key === Qt.Key_Up || (nav && event.key === Qt.Key_K)) move(-step)
        else if ((nav && event.key === Qt.Key_H) || (event.key === Qt.Key_Left && !search.text)) move(-1)
        else if ((nav && event.key === Qt.Key_L) || (event.key === Qt.Key_Right && !search.text)) move(1)
        else if (event.key === Qt.Key_PageDown || (ctrl && event.key === Qt.Key_D)) movePage(1)
        else if (event.key === Qt.Key_PageUp || (ctrl && event.key === Qt.Key_U)) movePage(-1)
        else if (ctrl && event.key === Qt.Key_Home) { selected = 0; reveal(true) }
        else if (ctrl && event.key === Qt.Key_End) { selected = Math.max(0, filtered.length - 1); reveal(true) }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) choose()
        else if (event.key === Qt.Key_F5) refresh()
        else return
        event.accepted = true
    }
    Keys.onPressed: event => handleKey(event)

    // Listing and thumbnail jobs can finish after the user has left their page.
    component PageProcess: Process {
        id: job
        required property string page
        required property string failureMessage
        property bool startedSuccessfully: false
        property bool pending: false
        property bool rerunQueued: false
        property bool exitReceived: false
        property bool collectsOutput: false
        property bool outputDone: true
        property bool succeeded: false
        property string output: ""
        signal collected(string text)
        function finish() {
            if (view.busy || !pending || running || !exitReceived || !outputDone) return
            pending = false
            const rerun = rerunQueued
            rerunQueued = false
            if (succeeded && collectsOutput) collected(output)
            if (rerun && view.page === page && !view.busy) start()
        }
        function reportFailure(message) {
            if (view.page === page && !view.busy && !view.error) view.error = message
        }
        function start() {
            if (pending || running) { rerunQueued = true; return }
            pending = true
            exitReceived = false
            outputDone = !collectsOutput
            startedSuccessfully = false
            succeeded = false
            output = ""
            startupCheck.restart()
            running = true
        }
        onStarted: { startedSuccessfully = true; startupCheck.stop() }
        onRunningChanged: if (!running) {
            Qt.callLater(job.checkStartup)
            Qt.callLater(job.finish)
        }
        function checkStartup() {
            if (pending && !startedSuccessfully && !running) {
                startupCheck.stop()
                reportFailure("Could not start " + command[0])
                exitReceived = true
                outputDone = true
                succeeded = false
                finish()
            }
        }
        onExited: (code, status) => {
            startupCheck.stop()
            succeeded = code === 0 && status === 0
            if (!succeeded) reportFailure(failureMessage)
            exitReceived = true
            // Let exit and collector callbacks unwind before reusing the process.
            Qt.callLater(job.finish)
        }
        // Quickshell does not emit exited when an executable is missing.
        property Timer startupCheck: Timer {
            interval: 500
            onTriggered: job.checkStartup()
        }
    }

    PageProcess {
        id: themeProc
        collectsOutput: true
        page: "Themes"
        failureMessage: "Could not load themes. Press F5 to retry."
        command: [view.bin, "--list-themes"]
        onCollected: text => {
            view.presets = text.split("\n").filter(Boolean)
            if (view.page === "Themes") view.rebuild()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                themeProc.output = text
                themeProc.outputDone = true
                Qt.callLater(themeProc.finish)
            }
        }
    }

    PageProcess {
        id: wallProc
        collectsOutput: true
        page: "Wallpapers"
        failureMessage: "Could not load wallpapers. Press F5 to retry."
        command: [view.bin, "--list-walls"]
        onCollected: text => {
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
            if (view.page === "Wallpapers") view.rebuild()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                wallProc.output = text
                wallProc.outputDone = true
                Qt.callLater(wallProc.finish)
            }
        }
    }

    Process {
        id: wallpaperProc
        property bool _started: false
        command: ["swww", "img", ""]
        onStarted: { _started = true; launchCheck.stop(); if (view.operationCancelled) signal(15) }
        onRunningChanged: if (!running && !_started) Qt.callLater(launchCheck.check)
        onExited: (code, status) => {
            launchCheck.stop()
            view.busy = false
            const effectiveCode = status === 0 ? code : -1
            if (effectiveCode === 0 && !view.operationCancelled) view.dismissed()
            else { view.error = view.operationError(effectiveCode, effectiveCode === 127 ? "Could not start swww" : "Could not set the wallpaper. Check that swww is running."); view.focusSearch() }
        }
    }
    PageProcess {
        id: thumbProc
        page: "Wallpapers"
        failureMessage: "Some previews could not be generated. Press F5 to retry."
        command: [view.bin, "--thumbs"]
        stdout: SplitParser { onRead: path => view.thumbnailReady(path) }
    }
    function finishApply() {
        if (!busy || !applyProc._exited || !applyProc.stderrDone) return
        launchCheck.stop()
        busy = false
        if (applyProc.exitCode === 0 && !operationCancelled) dismissed()
        else {
            error = operationError(applyProc.exitCode, applyProc.exitCode === 127 ? "Could not start " + bin : applyProc.errorText.trim().slice(-1200) || "Could not apply the theme. Check the theme engine and try again.")
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
        onStarted: { _started = true; launchCheck.stop(); if (view.operationCancelled) signal(15) }
        onRunningChanged: if (!running && !_started) Qt.callLater(launchCheck.check)
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (!applyProc._started) return
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
        onTriggered: check()
        function check() {
            if (view.busy && !process._started && !process.running) {
                stop()
                view.busy = false
                view.error = "Could not start " + process.command[0]
                view.focusSearch()
            }
        }
    }

    // Use the same scroll-unit sensitivity and easing for wheel and touchpad input.
    component Scroller: Item {
        id: sc
        required property Flickable flick
        property real target: 0
        property real rate: 32
        property bool smoothWheel: false
        property real wheelStep: flick.height * 0.45
        property real touchpadStep: 135
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
            const ticks = event.angleDelta.y !== 0 ? -event.angleDelta.y / 120 : -event.pixelDelta.y / 15
            if (ticks === 0) return false
            // Phase/device data keeps rounded-zero pixel frames on the
            // continuous-input scale too. Pixel deltas are a fallback hint.
            const continuous = event.pixelDelta.y !== 0
                || (event.phase !== undefined && event.phase !== Qt.NoScrollPhase)
                || (event.device && event.device.type === PointerDevice.TouchPad)
            const delta = ticks * (continuous ? touchpadStep : wheelStep)
            if (smoothWheel) {
                flick.cancelFlick()
                // Accumulate input, discard queued travel on reversal, and
                // keep the target near the visible viewport.
                const base = anim.running && (target - flick.contentY) * delta > 0
                    ? target : flick.contentY
                const maxLead = flick.height * 1.5
                target = limit(Math.max(flick.contentY - maxLead,
                    Math.min(flick.contentY + maxLead, base + delta)))
                rate = 28
                anim.running = target !== flick.contentY
            } else jump(flick.contentY + delta)
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
                sc.target = sc.limit(sc.target)
                const dist = sc.target - sc.flick.contentY
                if (Math.abs(dist) < 0.5) {
                    sc.flick.contentY = sc.target
                    running = false
                    return
                }
                const stepBy = dist * (1 - Math.exp(-frameTime * sc.rate))
                sc.flick.contentY = sc.limit(sc.flick.contentY + stepBy)
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool allowWhileBusy: false
        signal clicked()
        implicitHeight: 30
        implicitWidth: Math.max(30, chipLabel.implicitWidth + 18)
        radius: 8
        color: chipMouse.containsMouse ? view.faint : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.text
            color: view.accent
            font.family: view.uiFont
            font.pixelSize: 18
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: !view.busy || chip.allowWhileBusy
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Chip {
                visible: view.page !== "Home"
                text: "‹"
                onClicked: view.back()
            }
            TextField {
                id: search
                objectName: "pickerSearch"
                Layout.fillWidth: true
                implicitHeight: 40
                leftPadding: 34
                rightPadding: 10
                enabled: !view.busy
                selectByMouse: true
                font.family: view.uiFont
                font.pixelSize: 14
                color: view.ink
                selectionColor: view.accent
                selectedTextColor: view.accentText
                Text {
                    x: 12
                    height: parent.height
                    text: "⌕"
                    color: view.muted
                    font.pixelSize: 20
                    verticalAlignment: Text.AlignVCenter
                }
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
                    color: view.fieldColor
                    border.width: 1
                    border.color: search.activeFocus ? Qt.alpha(view.accent, 0.4) : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                }
                onTextChanged: view.rebuild()
                Keys.onPressed: event => view.handleKey(event)
            }
            Chip {
                objectName: "pickerClose"
                allowWhileBusy: true
                text: "×"
                onClicked: view.dismiss()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Scroller {
                id: gridScroll
                objectName: "wallpaperScroller"
                flick: grid
                smoothWheel: true
                wheelStep: grid.height * 0.65
            }
            Scroller { id: listScroll; smoothWheel: true; flick: themeList }

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
                    onWheel: event => { gridScroll.wheel(event); event.accepted = true }
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
                    readonly property bool hovered: tileMouse.containsMouse && !gridScroll.animating
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 6
                        color: tile.chosen ? Qt.alpha(view.ink, 0.08) : tile.hovered ? Qt.alpha(view.ink, 0.04) : Qt.alpha(view.ink, 0.02)
                        border.width: 1
                        border.color: tile.chosen ? view.accent : tile.hovered ? Qt.alpha(view.accent, 0.35) : "transparent"
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        PlainToolTip {
                            visible: tile.hovered
                            text: view.baseName(tile.modelData)
                            delay: 700
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -10
                            visible: img.status !== Image.Ready
                            text: "▧"
                            color: view.muted
                            font.pixelSize: 24
                        }
                        Image {
                            id: img
                            anchors.fill: parent
                            anchors.margins: 2
                            anchors.bottomMargin: 22
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(320, 180)
                            // Versioned URLs keep the cache while retrying new thumbnails safely.
                            source: view.thumbUrl(tile.modelData)
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            text: view.baseName(tile.modelData)
                            textFormat: Text.PlainText
                            font.family: view.uiFont
                            font.pixelSize: 11
                            color: view.ink
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 7
                            width: 20
                            height: 20
                            radius: 10
                            visible: tile.chosen
                            color: view.accent
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: view.accentText
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            id: tileMouse
                            onClicked: { view.selected = tile.index; view.focusSearch() }
                            onDoubleClicked: { view.selected = tile.index; view.choose() }
                        }
                    }
                }
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
                    onWheel: event => { listScroll.wheel(event); event.accepted = true }
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
                    width: themeList.width
                    height: view.rowHeight
                    readonly property bool chosen: view.selected === index
                    radius: 8
                    color: chosen ? Qt.alpha(view.accent, 0.12) : rowMouse.containsMouse ? view.faint : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Rectangle {
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 22
                        radius: 1.5
                        color: view.accent
                        visible: row.chosen
                    }
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData
                        textFormat: Text.PlainText
                        color: row.chosen ? view.accent : view.ink
                        font.family: view.uiFont
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { view.selected = row.index; view.focusSearch() }
                        onDoubleClicked: { view.selected = row.index; view.choose() }
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
            color: view.errorColor
            font.family: view.uiFont
            font.pixelSize: 11
        }
        Text {
            Layout.fillWidth: true
            visible: view.busy || (view.page === "Wallpapers" && thumbProc.pending)
            text: view.busy ? view.operation : "Preparing previews…"
            textFormat: Text.PlainText
            color: view.muted
            font.family: view.uiFont
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
