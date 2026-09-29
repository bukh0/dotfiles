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
        function inspect(id) {}
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
            view.grabToImage(result => {
                result.saveToFile("/tmp/quickshell-clipboard-preview.png")
                console.log("CLIPBOARD UI PASS")
                Qt.quit()
            })
        }
    }
}
