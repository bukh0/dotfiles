import QtQuick
import Quickshell.Io

// One-shot jobs only: long-lived monitors retain their streaming parsers.
// Completion is deferred until exit and both output streams have settled.
Process {
    id: job
    property bool pending: false
    property bool startedSuccessfully: false
    property bool cancelled: false
    property bool _exited: false
    property bool _stdoutDone: false
    property bool _stderrDone: false
    property int _code: -1
    property int _status: -1
    property string _output: ""
    property string _error: ""
    signal completed(var result)

    function start(args) {
        if (pending || running) return false
        startedSuccessfully = false
        cancelled = false
        _exited = false
        _stdoutDone = false
        _stderrDone = false
        _code = -1
        _status = -1
        _output = ""
        _error = ""
        pending = true
        startupCheck.restart()
        exec(args)
        return true
    }
    function cancel() {
        if (!pending) return
        cancelled = true
        running = false
    }
    function finish() {
        if (!pending || running) return
        if (startedSuccessfully && (!_exited || !_stdoutDone || !_stderrDone)) return
        startupCheck.stop()
        const result = {
            started: startedSuccessfully,
            cancelled: cancelled,
            success: startedSuccessfully && !cancelled && _status === 0 && _code === 0,
            exitCode: _code, exitStatus: _status,
            stdout: _output, stderr: _error
        }
        pending = false
        completed(result)
    }
    onStarted: { startedSuccessfully = true; startupCheck.stop() }
    onRunningChanged: if (!running) settle.restart()
    onExited: (code, status) => {
        _code = code
        _status = status
        _exited = true
        settle.restart()
    }
    stdout: StdioCollector {
        onStreamFinished: {
            job._output = job.startedSuccessfully ? text : ""
            job._stdoutDone = true
            settle.restart()
        }
    }
    stderr: StdioCollector {
        onStreamFinished: {
            job._error = job.startedSuccessfully ? text : ""
            job._stderrDone = true
            settle.restart()
        }
    }
    property Timer settle: Timer { interval: 0; onTriggered: job.finish() }
    // Failed spawns do not reliably emit exited.
    property Timer startupCheck: Timer {
        interval: 500
        onTriggered: if (!job.startedSuccessfully && !job.running) job.finish()
    }
}
