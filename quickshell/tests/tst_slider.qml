import QtQuick
import QtTest
import "../profiles/default" as Config

Item {
    width: 420
    height: 100
    Config.SliderRow {
        id: slider
        width: 400
        minValue: 0.01
        value: 0.5
        onDragged: val => value = val
        onCommitted: val => value = val
    }
    SignalSpy { id: commits; target: slider; signalName: "committed" }
    TestCase {
        name: "Slider"
        when: windowShown
        function test_pointerMapping() {
            const track = slider.children[1]
            mousePress(track, track.width / 2, track.height / 2)
            verify(slider.isDragging)
            fuzzyCompare(slider.visualValue, 0.5, 0.01)
            mouseMove(track, track.width - 1, track.height / 2)
            fuzzyCompare(slider.visualValue, 1, 0.01)
            mouseRelease(track, track.width - 1, track.height / 2)
            verify(!slider.isDragging)
            compare(commits.count, 1)
            fuzzyCompare(slider.value, 1, 0.01)
            const fullWidth = track.width
            mouseClick(track, 0, track.height / 2)
            compare(slider.value, 0.01)
            compare(track.width, fullWidth)
        }
    }
}
