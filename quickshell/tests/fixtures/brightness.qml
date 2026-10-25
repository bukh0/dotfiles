import QtQuick
import Quickshell
import Quickshell.Io
import "profile" as Config

ShellRoot {
    id: root
    property int step: 0
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    FileView { id: setpoint; blockAllReads: true; path: Quickshell.env("TEST_BACKLIGHT") + "/mock/brightness" }
    FileView { id: writes; blockAllReads: true; path: Quickshell.env("TEST_WRITES") }
    FileView { id: failure; path: Quickshell.env("TEST_FAILURE"); atomicWrites: false }
    Config.BrightnessSlider { id: first }
    Component { id: sliderComponent; Config.BrightnessSlider {} }
    property var second
    Component.onCompleted: Config.BrightnessService.discover()
    Timer {
        interval: 650
        running: true
        repeat: true
        onTriggered: {
            try {
                const service = Config.BrightnessService
                switch (root.step++) {
                case 0:
                    check(service.available, "backlight discovery failed")
                    check(service.brightness === 1, "readback used actual_brightness instead of setpoint")
                    // Many events in one frame should become one write.
                    for (let i = 10; i <= 60; i++) service.request(i / 100)
                    break
                case 1:
                    setpoint.reload(); writes.reload()
                    check(Number(setpoint.text()) === 60, "latest brightness was not applied: " + setpoint.text() + " UI: " + service.brightness + " writes: " + writes.text())
                    check(writes.text().trim().split("\n").length === 1, "drag writes were not coalesced")
                    check(service.brightness === 0.6, "readback changed the requested brightness")
                    service.request(NaN)
                    check(service.brightness === 0.6, "NaN request changed brightness")
                    service.request(0)
                    break
                case 2:
                    setpoint.reload()
                    check(Number(setpoint.text()) === 1, "minimum brightness was not clamped")
                    service.request(0.2)
                    later.start()
                    break
                case 3:
                    setpoint.reload()
                    check(Number(setpoint.text()) === 90, "latest request during an in-flight write was lost")
                    failure.setText("fail")
                    break
                case 4:
                    service.request(0.4)
                    break
                case 5:
                    check(service.brightness === 0.9, "failed write was not reconciled")
                    failure.setText("")
                    break
                case 6:
                    service.request(0.4)
                    break
                case 7:
                    setpoint.reload()
                    check(Number(setpoint.text()) === 40, "retry after failed write was dropped")
                    // An idle panel disappearing must not end another panel's drag.
                    root.second = sliderComponent.createObject(root)
                    first.children[0].isDragging = true
                    root.second.destroy()
                    break
                case 8:
                    check(service.interacting, "destroying another panel ended the active drag")
                    first.children[0].isDragging = false
                    check(!service.interacting, "interaction count leaked")
                    setpoint.setText("75\n")
                    break
                case 9:
                    // Poll fallback also covers external hotkeys on sysfs.
                    break
                case 10:
                    check(service.brightness === 0.75, "external brightness change was not synchronized")
                    console.log("REGRESSION PASS: brightness")
                    Qt.quit()
                }
            } catch (error) {
                console.error("REGRESSION FAIL:", error.message)
                Qt.quit()
            }
        }
    }
    Timer { id: later; interval: 80; onTriggered: Config.BrightnessService.request(0.9) }
}
