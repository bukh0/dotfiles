"""Load actual window wrappers on a private bus without changing the running shell."""
import os
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile
ROOT = Path(__file__).resolve().parent.parent
if os.environ.get("QS_PROFILE_TEST_BUS") != "1":
    # No service directories: this bus must not activate desktop portals.
    with tempfile.TemporaryDirectory(prefix="qs-profile-bus-") as directory:
        config = Path(directory) / "bus.conf"
        config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=' + directory +
            '</listen><policy context="default"><allow send_destination="*"/>'
            '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        raise SystemExit(subprocess.run(["dbus-run-session", "--config-file", str(config),
            "--", sys.executable, __file__],
            env=dict(os.environ, QS_PROFILE_TEST_BUS="1")).returncode)
with tempfile.TemporaryDirectory(prefix="qs-profile-load-") as directory:
    p = Path(directory)
    for profile in ["default", "alt"]:
        profile_link = p / profile
        profile_link.symlink_to(ROOT / "profiles" / profile, target_is_directory=True)
        (p / "shell.qml").write_text('''import QtQuick
import Quickshell
import "''' + profile + '''" as Config
ShellRoot {
 Config.Bar {
  id: bar
  visible: Config.Theme.floatingBar && Quickshell.env("QS_TEST_BAR_MASK") === "1"
  exclusionMode: ExclusionMode.Ignore
 }
 Config.NotificationHistory {}
 Config.BatteryAlerts {}
 Config.NotificationDrawer { id: drawer; visible: false }
 Config.NotificationPopup { id: popup; visible: false }
 Timer { interval: 500; running: true; onTriggered: {
  if (Config.Theme.floatingBar && !bar.mask) console.error("FAIL missing floating bar input mask")
  else if (!Config.Theme.floatingBar && bar.mask) console.error("FAIL classic bar must retain full input")
  else {
   if (bar.visible) {
    const regions = bar.mask.regions
    if (regions.length !== 5) { console.error("FAIL missing extended hit regions"); Qt.quit(); return }
    const bell = regions[3].item
    const clock = regions[1].item
    const bellPoint = bell.mapToItem(null, bell.width / 2, bell.height - 1)
    const clockTop = clock.mapToItem(null, clock.width / 2, -5)
    const clockLeft = clock.mapToItem(null, -5, clock.height / 2)
    console.log("MASK_POINTS", JSON.stringify({
     inside: [[bellPoint.x, bellPoint.y], [clockTop.x, clockTop.y], [clockLeft.x, clockLeft.y]],
     outside: [[0, 0], [0, bar.height - 1], [bar.width / 4, 0]]
    }))
   }
   console.log("PROFILE PASS")
  }
  Qt.quit()
 } }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="wayland", XDG_RUNTIME_DIR=directory, XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory)
        env["WAYLAND_DISPLAY"] = str(Path(os.environ["XDG_RUNTIME_DIR"]) / os.environ["WAYLAND_DISPLAY"])
        env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        probe = profile == "alt" and os.environ.get("QS_TEST_BAR_MASK") == "1"
        if probe:
            env["WAYLAND_DEBUG"] = "1"
        result = subprocess.run(["quickshell", "-p", str(p)], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        if probe:
            # Assert the union actually submitted to the compositor, rather
            # than inferring it from QML geometry or synthetic child clicks.
            points = json.loads(re.search(r"MASK_POINTS (\{[^\n]+\})", output).group(1))
            regions, submitted = {}, []
            for line in output.splitlines():
                created = re.search(r"create_region\(new id wl_region#(\d+)\)", line)
                added = re.search(r"wl_region#(\d+)\.add\((-?\d+), (-?\d+), (\d+), (\d+)\)", line)
                applied = re.search(r"set_input_region\(wl_region#(\d+)\)", line)
                if created:
                    regions[created[1]] = []
                if added:
                    regions.setdefault(added[1], []).append(tuple(map(int, added.groups()[1:])))
                if applied:
                    submitted.append(list(regions[applied[1]]))
            def contains(rects, point):
                px, py = point
                return any(x <= px < x + w and y <= py < y + h for x, y, w, h in rects)
            assert any(all(contains(rects, p) for p in points["inside"]) and
                       not any(contains(rects, p) for p in points["outside"])
                       for rects in submitted), (points, submitted)
            print("PASS Wayland region includes bell seam and clock padding, excluding unrelated margins")
        else:
            print(profile, output)
        assert result.returncode == 0 and "PROFILE PASS" in output and "FAIL " not in output
        assert "ReferenceError" not in output and "TypeError" not in output and "Unable to assign" not in output
