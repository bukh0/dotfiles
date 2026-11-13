import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: service
    property var entries: []
    property var preview: ({})
    property string previewId: ""
    property string loadedPreviewId: ""
    property string requestedId: ""
    property string error: ""
    property string address: ""
    property bool busy: actionProcess.pending
    property bool loading: listProcess.pending
    property bool previewLoading: requestedId !== "" && (previewProcess.pending || previewDelay.running)
    property bool pasteAfterCopy: false
    property bool refreshPending: false
    property string action: ""
    property string helper: Quickshell.shellPath("backend.py")
    signal copied(bool pasteRequested)
    signal pasted()

    function result(text) {
        try {
            const data = JSON.parse(text)
            return data && typeof data === "object" && !Array.isArray(data) ? data : {error: "Could not read the clipboard response."}
        }
        catch (_) { return {error: "Could not read the clipboard response."} }
    }
    function refresh() {
        if (listProcess.pending) { refreshPending = true; return }
        refreshPending = false
        listProcess.start(["python3", helper, "list"])
    }
    function inspect(entryId) {
        if (requestedId === entryId && !preview.error) return
        requestedId = entryId
        loadedPreviewId = ""
        preview = {}
        previewDelay.stop()
        if (entryId) previewDelay.restart()
    }

    function perform(operation, entryId) {
        if (busy) return
        error = ""
        action = operation
        actionProcess.start(["python3", helper, operation].concat((entryId || operation === "paste") ? [entryId] : []))
    }
    function choose(entryId, shouldPaste) {
        if (!entryId || busy) return
        pasteAfterCopy = shouldPaste
        perform("copy", entryId)
    }
    Component.onCompleted: {
        const context = Quickshell.env("QS_CLIPBOARD_CONTEXT")
        if (context) address = result(context).address || ""
        else contextProcess.start(["python3", helper, "context"])
        refresh()
    }
    component JsonProcess: ManagedProcess {
        signal decoded(var data)
        onCompleted: result => {
            const data = !result.started
                ? {error: "Could not start the clipboard helper. Check that Python 3 is installed."}
                : !result.success
                ? {error: "Clipboard helper exited unexpectedly. Try again."}
                : service.result(result.stdout)
            decoded(data)
        }
    }
    JsonProcess {
        id: contextProcess
        onDecoded: data => { service.address = data.address || "" }
    }
    JsonProcess {
        id: listProcess
        onDecoded: data => {
            if (data.error) service.error = data.error
            else if (!data.entries || typeof data.entries.length !== "number") service.error = "Could not read clipboard entries."
            else { service.error = ""; service.entries = data.entries }
            if (service.refreshPending) Qt.callLater(service.refresh)
        }
    }
    Timer {
        id: previewDelay
        interval: 100
        onTriggered: {
            if (previewProcess.pending || !service.requestedId) return
            service.previewId = service.requestedId
            previewProcess.start(["python3", service.helper, "preview", service.previewId])
        }
    }
    JsonProcess {
        id: previewProcess
        onDecoded: data => {
            if (service.previewId === service.requestedId && service.requestedId !== "") {
                service.loadedPreviewId = service.previewId
                previewDelay.stop()
                service.preview = data
            }
            if (service.requestedId !== "" && service.loadedPreviewId !== service.requestedId)
                previewDelay.restart()
        }
    }
    JsonProcess {
        id: actionProcess
        onDecoded: data => {
            if (data.error) { service.error = data.error; return }
            if (service.action === "copy") service.copied(service.pasteAfterCopy)
            else if (service.action === "paste") service.pasted()
            else { service.error = ""; service.refresh() }
        }
    }
}
