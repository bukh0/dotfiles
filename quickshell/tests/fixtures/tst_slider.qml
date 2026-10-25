import QtQuick
import QtTest
import "profile" as Config

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
        function init() { commits.clear(); slider.preferVerticalScroll=false; slider.minValue=0.01; slider.maxValue=1 }
        function test_externalAmplification() {
            slider.value = 1.2
            compare(slider.visualValue, 1)
            compare(slider.children[2].text, "100%")
            slider.value = -0.2
            compare(slider.visualValue, slider.minValue)
        }
        function test_wheelMapping() {
            const track = slider.children[1]
            slider.value = 0.5
            mouseWheel(track, track.width / 2, track.height / 2, 0, 120)
            fuzzyCompare(slider.value, 0.55, 0.001)
            mouseWheel(track, track.width / 2, track.height / 2, 0, 0)
            fuzzyCompare(slider.value, 0.55, 0.001)
            slider.value = slider.minValue
            mouseWheel(track, track.width / 2, track.height / 2, 0, -120)
            compare(slider.value, slider.minValue)
        }
        function test_overflowDefersWheel() {
            const track = slider.children[1]
            slider.value=0.5
            slider.preferVerticalScroll=true
            mouseWheel(track,track.width/2,track.height/2,0,120)
            compare(slider.value,0.5)
            slider.preferVerticalScroll=false
            mouseWheel(track,track.width/2,track.height/2,0,120)
            fuzzyCompare(slider.value,0.55,0.001)
        }
        function test_nonzeroRange() {
            slider.minValue = 0.25
            slider.maxValue = 1.25
            slider.value = 0.25
            compare(slider.position, 0)
            slider.value = 1.25
            compare(slider.position, 1)
            slider.value = 0.75
            compare(slider.position, 0.5)
            const track = slider.children[1]
            mouseClick(track, track.width / 2, track.height / 2)
            fuzzyCompare(slider.value, 0.75, 0.005)
        }
        function test_zeroRange() {
            slider.minValue = 0.5
            slider.maxValue = 0.5
            slider.value = 0.5
            compare(slider.position, 0)
            const track = slider.children[1]
            mouseClick(track, track.width / 2, track.height / 2)
            compare(slider.value, 0.5)
        }
        function test_pointerMapping() {
            const track = slider.children[1]
            mousePress(track, track.width / 2, track.height / 2)
            verify(slider.isDragging)
            fuzzyCompare(slider.visualValue, 0.505, 0.005)
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
