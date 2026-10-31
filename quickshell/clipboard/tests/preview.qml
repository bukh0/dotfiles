//@ pragma UseQApplication
import QtQuick
import Quickshell
import ".."

ShellRoot {
    Item {
        id: mock
        property var entries: [
            {id: "8", kind: "text", label: "Good ideas deserve a place to land."},
            {id: "7", kind: "link", label: "https://quickshell.org/docs"},
            {id: "6", kind: "text", label: "const palette = { accent: '#7aa2f7' };"},
            {id: "5", kind: "image", label: "[[ binary data 240 KiB png 1920x1080 ]]"},
            {id: "4", kind: "text", label: "Design notes — a quieter desktop, a clearer mind."},
            {id: "3", kind: "text", label: "Meeting notes\nKeep the little details."},
            {id: "2", kind: "link", label: "https://github.com/sentriz/cliphist"},
            {id: "1", kind: "text", label: "<b>This stays plain text</b>"}
        ]
        property var preview: ({text: "Good ideas deserve a place to land.\n\nA thought, a link, a few lines of code.\nEverything you copy, ready when you need it.", size: 127})
        property bool loading: false
        property bool previewLoading: false
        property bool busy: false
        property string error: ""
        property var inspections: []
        function inspect(id) { inspections.push(id) }
        function choose(id, paste) {}
        function perform(action, id) {}
        function refresh() {}
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 710
        color: "#10111a"
        ClipboardView {
            id: view
            anchors.centerIn: parent
            width: 940
            height: 650
            service: mock
        }
    }
    Timer {
        interval: 700
        running: true
        onTriggered: {
            if (view.filtered.length !== 8) throw new Error("Initial entries missing")
            view.category = "image"
            if (view.filtered.length !== 1 || view.current.id !== "5") throw new Error("Image filter failed")
            view.category = "text"
            if (view.filtered.length !== 7) throw new Error("Text filter failed")
            view.category = "all"
            view.selected = 0
            view.move(100)
            if (view.selected !== 7) throw new Error("Selection bounds failed")
            view.move(-100)

            // Reset selection against the new results, without previewing an
            // intermediate old/new row. Also exercise preservation on refresh.
            function findSearch(item) {
                if (item.objectName === "clipboardSearch") return item
                for (const child of item.children || []) { const found = findSearch(child); if (found) return found }
                return null
            }
            const search = findSearch(view)
            mock.entries = [
                {id: "a", kind: "text", label: "Alpha"},
                {id: "b", kind: "image", label: "Beta one"},
                {id: "c", kind: "image", label: "Beta two"},
                {id: "d", kind: "text", label: "Delta"}
            ]
            view.selected = 3
            mock.inspections = []
            search.text = "Beta"
            if (view.selected !== 0 || view.current.id !== "b" || JSON.stringify(mock.inspections) !== '["b"]')
                throw new Error("Search inspected an intermediate selection")
            view.selected = 1
            mock.inspections = []
            search.text = ""
            if (view.selected !== 0 || view.current.id !== "a" || JSON.stringify(mock.inspections) !== '["a"]')
                throw new Error("Clearing search preserved the previous first result")
            view.selected = 3
            mock.inspections = []
            view.category = "image"
            if (view.selected !== 0 || view.current.id !== "b" || JSON.stringify(mock.inspections) !== '["b"]')
                throw new Error("Category inspected an intermediate selection")
            view.selected = 1
            mock.inspections = []
            mock.entries = [mock.entries[2], mock.entries[1]]
            if (view.selected !== 0 || view.current.id !== "c" || JSON.stringify(mock.inspections) !== '["c"]')
                throw new Error("Refresh failed to preserve the selected entry")
            view.category = "all"
            mock.entries = Array.from({length: 80}, (_, i) => ({id: String(i), kind: "text", label: "Entry " + i}))
            view.selected = 70
            view.rebuild()
            scrollCheck.start()

        }
    }
    Timer {
        id: scrollCheck
        interval: 200
        onTriggered: {
            function find(item) {
                if (item.objectName === "clipboardHistory") return item
                for (const child of item.children || []) { const result = find(child); if (result) return result }
                return null
            }
            const history = find(view)
            const row = history.itemAtIndex(view.selected)
            if (!row || row.y < history.contentY || row.y + row.height > history.contentY + history.height)
                throw new Error("Rebuild left selection off screen")
            view.category = "image"
            if (view.filtered.length) throw new Error("Expected empty image filter")
            view.move(1)
            if (view.selected !== 0) throw new Error("Empty selection moved")
            view.confirmClear = true
            function findSearch(item) {
                if (item.objectName === "clipboardSearch") return item
                for (const child of item.children || []) { const found = findSearch(child); if (found) return found }
                return null
            }
            if (!findSearch(view).readOnly) throw new Error("Modal allows search edits")
            console.log("CLIPBOARD UI PASS")
            Qt.quit()
        }
    }
}
