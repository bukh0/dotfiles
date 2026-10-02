import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: service
    property var entries: []
    property var preview: ({})
    property string previewId: ""
    property string requestedId: ""
    property string error: ""
    property string address: ""
    property bool busy: actionProcess.running
    property bool loading: listProcess.running
    property bool previewLoading: previewProcess.running || previewDelay.running
    property bool pasteAfterCopy: false
    property bool refreshPending: false
    property string action: ""
    property string helper: Quickshell.shellPath("backend.py")
    signal copied(bool pasteRequested)
    signal pasted()

    function result(text) {
        try { return JSON.parse(text) }
        catch (_) { return {error: "Could not read the clipboard response."} }
    }
    function refresh() {
        if (listProcess.running) { refreshPending = true; return }
        refreshPending = false
        listProcess.exec(["python3", helper, "list"])
    }
    function inspect(entryId) {
        if (requestedId === entryId && !preview.error) return
        requestedId = entryId
        preview = {}
        previewDelay.restart()
    }
    function perform(operation, entryId) {
        if (busy) return
        error = ""
        action = operation
        actionProcess.exec(["python3", helper, operation].concat(entryId || operation === "paste" ? [entryId] : []))
    }
    function choose(entryId, shouldPaste) {
        if (!entryId || busy) return
        pasteAfterCopy = shouldPaste
        perform("copy", entryId)
    }
    Component.onCompleted: {
        const context = Quickshell.env("QS_CLIPBOARD_CONTEXT")
        if (context) address = result(context).address || ""
        else contextProcess.exec(["python3", helper, "context"])
        refresh()
    }
    Process {
        id: contextProcess
        stdout: StdioCollector { onStreamFinished: service.address = service.result(text).address || "" }
    }
    Process {
        id: listProcess
        onExited: { if (service.refreshPending) Qt.callLater(() => service.refresh()) }
        stdout: StdioCollector {
            onStreamFinished: {
                const data = service.result(text)
                if (data.error) service.error = data.error
                else { service.error = ""; service.entries = data.entries }
            }
        }
    }
    Timer {
        id: previewDelay
        interval: 100
        onTriggered: {
            if (previewProcess.running || !service.requestedId) return
            service.previewId = service.requestedId
            previewProcess.exec(["python3", service.helper, "preview", service.previewId])
        }
    }
    Process {
        id: previewProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (service.previewId === service.requestedId)
                    service.preview = service.result(text)
            }
        }
        onExited: { if (service.previewId !== service.requestedId) previewDelay.restart() }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const data = service.result(text)
                if (data.error) { service.error = data.error; return }
                if (service.action === "copy") service.copied(service.pasteAfterCopy)
                else if (service.action === "paste") service.pasted()
                else { service.error = ""; service.refresh() }
            }
        }
    }
}
