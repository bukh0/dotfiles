"""Exercise both picker branches with mocked wallpaper/theme commands."""
import os
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="picker-flow-") as directory:
    p = pathlib.Path(directory)
    (p / "picker").mkdir()
    (p / "profiles").mkdir()
    shutil.copytree(ROOT / "profiles/default", p / "profiles/default")
    shutil.copytree(ROOT / "profiles/alt", p / "profiles/alt")
    for name in ("PickerView.qml", "qmldir", "Colors.qml"):
        shutil.copyfile(ROOT / "picker" / name, p / "picker" / name)
    engine = p / "engine"
    engine.write_text('''#!/bin/sh
case "$1" in
--list-walls) printf '/tmp/wall.png\\t/tmp/thumb.jpg\\n';;
--list-themes) printf 'Matugen\\npywal\\nPreset\\n';;
--apply) printf 'theme:%s:%s\\n' "$2" "$3" >> "$TEST_CALLS"; printf 'mock theme error\\n' >&2; exit 1;;
esac
''')
    engine.chmod(0o755)
    swww = p / "swww"
    swww.write_text('''#!/bin/sh
printf 'wallpaper:%s\\n' "$2" >> "$TEST_CALLS"
exit 1
''')
    swww.chmod(0o755)
    (p / "shell.qml").write_text('''import QtQuick
import Quickshell
import "picker"
ShellRoot {
 Window { visible: true; width: 900; height: 600
  PickerView { id: view; anchors.fill: parent; bin: "''' + str(engine) + '''" }
 }
 function check(ok, message) { if (!ok) { console.error("FLOW FAIL", message); Qt.quit() } }
 function select(value) {
  view.selected = view.filtered.indexOf(value)
  check(view.selected >= 0, "Missing choice " + value)
  view.choose()
 }
 Timer { interval: 700; running: true; repeat: true; property int step: 0
  onTriggered: {
   switch (step++) {
   case 0:
    check(view.page === "Home", "Initial menu")
    select("Wallpaper"); break
   case 1:
    check(view.page === "Wallpapers" && view.generator === "", "Wallpaper-only branch")
    view.choose(); break
   case 2:
    check(!view.busy && view.error.length > 0, "Wallpaper error recovery")
    view.back(); select("Theme"); break
   case 3:
    check(view.page === "Themes", "Theme list")
    select("Preset"); break
   case 4:
    check(!view.busy && view.error === "mock theme error", "Preset application")
    select("Matugen"); break
   case 5:
    check(view.page === "Wallpapers" && view.generator === "Matugen", "Generated theme branch")
    view.choose(); break
   case 6:
    check(!view.busy && view.error === "mock theme error", "Generated theme application")
    view.back(); check(view.page === "Themes", "Return to themes")
    view.back(); select("Wallpaper"); break
   case 7:
    check(view.generator === "", "Generator must not leak into wallpaper-only branch")
    view.choose(); break
   case 8:
    check(!view.busy, "Final action completed")
    console.log("FLOW PASS"); Qt.quit()
   }
  }
 }
}
''')
    calls = p / "calls"
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=directory,
               PATH=directory + ":" + os.environ["PATH"], TEST_CALLS=str(calls))
    result = subprocess.run([shutil.which("quickshell"), "-p", str(p / "shell.qml")],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert "FLOW PASS" in output and "FLOW FAIL" not in output, output
    assert calls.read_text().splitlines() == [
        "wallpaper:/tmp/wall.png", "theme:Preset:",
        "theme:Matugen:/tmp/wall.png", "wallpaper:/tmp/wall.png"], calls.read_text()
    print("PASS: wallpaper-only, preset, generated theme, back navigation, and error recovery")
