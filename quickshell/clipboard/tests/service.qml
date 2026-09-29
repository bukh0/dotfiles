import QtQuick
import Quickshell
import "."

ShellRoot {
    ClipboardService {
        id: service
        helper: Quickshell.shellPath("fake_backend.py")
        property int copies: 0
        onCopied: copies++
    }
    Timer {
        id: steps
        interval: 120
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            step++
            if (step === 2) {
                if (service.entries.length !== 2 || service.address !== "0x123") throw new Error("Initial load failed")
                service.inspect("1")
            }
            if (step === 4) service.inspect("2")
            if (step === 9) {
                if (service.preview.text !== "second") throw new Error("Stale preview won the race")
                service.choose("bad", true)
            }
            if (step === 12) {
                if (!service.error || service.copies) throw new Error("Copy failure closed the popup")
                service.choose("2", false)
            }
            if (step === 15) {
                if (service.error || service.copies !== 1) throw new Error("Copy recovery failed")
                console.log("CLIPBOARD SERVICE PASS")
                Qt.quit()
            }
        }
    }
}
