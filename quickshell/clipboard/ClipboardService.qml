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
    // EOF and process exit can arrive in either order. Publish exactly once,
    // after both, and release pending before invoking callers.
    component JsonProcess: Process {
        id: job
        property bool pending: false
        property bool exited: false
        property bool outputDone: false
        property bool startedSuccessfully: false
        property bool failed: false
        property string output: ""
        signal completed(var data)
        function start(args) {
            if (pending || running) return
            exited = false
            outputDone = false
            startedSuccessfully = false
            failed = false
            output = ""
            pending = true
            startupCheck.restart()
            exec(args)
        }
        function finish() {
            if (!pending || running || !exited || !outputDone) return
            const data = failed ? {error: "Clipboard helper exited unexpectedly. Try again."} : service.result(output)
            pending = false
            completed(data)
        }
        onStarted: { startedSuccessfully = true; startupCheck.stop() }
        onRunningChanged: if (!running) Qt.callLater(job.finish)
        onExited: (code, status) => {
            startupCheck.stop()
            failed = code !== 0 || status !== 0
            exited = true
            Qt.callLater(job.finish)
        }
        stdout: StdioCollector {
            onStreamFinished: {
                job.output = text
                job.outputDone = true
                Qt.callLater(job.finish)
            }
        }
        property Timer startupCheck: Timer {
            interval: 500
            onTriggered: {
                if (job.pending && !job.startedSuccessfully && !job.running) {
                    job.pending = false
                    job.completed({error: "Could not start the clipboard helper. Check that Python 3 is installed."})
                }
            }
        }
    }
    JsonProcess {
        id: contextProcess
        onCompleted: data => { service.address = data.address || "" }
    }
    JsonProcess {
        id: listProcess
        onCompleted: data => {
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
        onCompleted: data => {
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
        onCompleted: data => {
            if (data.error) { service.error = data.error; return }
            if (service.action === "copy") service.copied(service.pasteAfterCopy)
            else if (service.action === "paste") service.pasted()
            else { service.error = ""; service.refresh() }
        }
    }
}
