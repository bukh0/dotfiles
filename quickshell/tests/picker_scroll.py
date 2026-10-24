"""Exercise wallpaper wheel easing, reversal, touchpad precision and bounds."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="picker-scroll-") as directory:
    root = Path(directory)
    picker = root / "picker"
    picker.mkdir()
    for name in ("PlainToolTip.qml", "PickerView.qml", "qmldir", "Colors.qml"):
        shutil.copyfile(ROOT / "picker" / name, picker / name)
    (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "picker"
ShellRoot {
    Window {
        visible: true; width: 820; height: 540
        PickerView { id: view; anchors.fill: parent; bin: "/bin/true" }
    }
    property int failures: 0
    function check(ok, message) {
        if (!ok) { failures++; console.error("SCROLL FAIL", message) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    function wheel(pixels, angle) {
        return {pixelDelta: {y: pixels}, angleDelta: {y: angle}}
    }
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        property real settledPosition: 0
        onTriggered: {
            const grid = find(view, "wallpaperGrid")
            const scroll = find(view, "wallpaperScroller")
            const search = find(view, "pickerSearch")
            switch (step++) {
            case 0:
                view.page = "Wallpapers"
                view.walls = Array.from({length: 1200}, (_, i) => "Wallpaper-" + i)
                view.rebuild(); break
            case 1:
                check(grid.contentHeight > grid.height, "Large wallpaper grid is scrollable")
                check(scroll.wheel(wheel(0, -120)), "Wheel event accepted")
                check(scroll.target > grid.height * 0.45, "Wheel travels farther than the previous implementation")
                check(grid.contentY < scroll.target, "Wheel step animates instead of jumping")
                interval = 80; break
            case 2:
                check(grid.contentY > 0 && grid.contentY < scroll.target, "Wheel advances through intermediate positions")
                interval = 500; break
            case 3:
                check(Math.abs(grid.contentY - scroll.target) < 0.5 && !scroll.animating, "Animation settles and stops")
                for (let i = 0; i < 30; i++) scroll.wheel(wheel(0, -120))
                check(scroll.target - grid.contentY <= grid.height * 1.5 + 0.01, "Rapid ticks cannot queue excessive travel")
                scroll.wheel(wheel(0, 120))
                check(scroll.target < grid.contentY, "Reversal discards forward travel immediately")
                break
            case 4:
                scroll.jump(500.25)
                scroll.wheel(wheel(-0.5, 0))
                check(Math.abs(grid.contentY - 500.25) < 0.01, "Continuous input follows the configured easing")
                scroll.wheel(wheel(0, -120))
                scroll.wheel(wheel(-1.25, 0))
                settledPosition = grid.contentY
                check(Math.abs(settledPosition - 500.25) < 0.01, "Continuous input does not jump during wheel easing")
                break
            case 5:
                check(grid.contentY > settledPosition && Math.abs(grid.contentY - scroll.target) < 0.5, "Continuous input settles at its scaled target")
                scroll.jump(1e9)
                const end = grid.originY + grid.contentHeight - grid.height
                scroll.wheel(wheel(0, -120))
                check(Math.abs(scroll.target - end) < 0.01, "Bottom bound is respected")
                scroll.wheel(wheel(0, 120))
                search.text = "Wallpaper-1199"; break
            case 6:
                check(view.filtered.length === 1 && Math.abs(grid.contentY - grid.originY) < 0.5,
                    "Filtering during animation resets the scroll bounds")
                search.clear(); break
            case 7:
                view.handleKey({key: Qt.Key_End, modifiers: Qt.ControlModifier, accepted: false})
                break
            case 8:
                const tile = grid.itemAtIndex(view.selected)
                check(tile && tile.y >= grid.contentY - 1 && tile.y + tile.height <= grid.contentY + grid.height + 1,
                    "Keyboard navigation still reveals the last wallpaper")
                console.log(failures ? "SCROLL FAILED" : "SCROLL PASS")
                Qt.quit()
            }
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory)
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["quickshell", "-p", str(root / "shell.qml")], env=env,
                            capture_output=True, text=True, timeout=12)
    output = result.stdout + result.stderr
    assert "SCROLL PASS" in output and "SCROLL FAIL" not in output, output
    print("PASS: smooth wheel motion, rapid input, reversal, continuous touchpad easing, filtering and keyboard reveal")
