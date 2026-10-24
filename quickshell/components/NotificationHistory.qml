import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    property bool ready: false
    FileView {
        id: store
        path: root.directory + "/notifications.json"
        preload: false
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }
    Process {
        command: ["mkdir", "-p", "-m", "700", root.directory]
        running: true
        onExited: (code, status) => {
            if (code !== 0 || status !== 0) { console.warn("Could not create notification history directory"); return }
            try { NotificationDaemon.restoreHistory(store.text()) } catch (_) {}
            root.ready = true
            saveDelay.restart()
        }
    }
    function save() {
        if (ready) store.setText(NotificationDaemon.historyJson())
    }
    Timer { id: saveDelay; interval: 600; onTriggered: root.save() }
    Connections {
        target: NotificationDaemon.notificationModel
        function onCountChanged() { if (root.ready) saveDelay.restart() }
        function onDataChanged() { if (root.ready) saveDelay.restart() }
        function onRowsMoved() { if (root.ready) saveDelay.restart() }
    }
    Component.onDestruction: save()
}
