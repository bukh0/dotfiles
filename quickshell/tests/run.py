#!/usr/bin/env python3
"""Isolated regressions: never write to real backlights or network services."""
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(command, env, marker=None):
    result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=25)
    print(result.stdout, end="")
    if result.returncode or (marker and marker not in result.stdout):
        raise SystemExit(f"Failed: {command}")


with tempfile.TemporaryDirectory(prefix="quickshell-tests-") as directory:
    stage = Path(directory)
    profile = stage / "profile"
    profile.mkdir()
    backlight = stage / "backlight" / "mock"
    backlight.mkdir(parents=True)
    (backlight / "brightness").write_text("100\n")
    (backlight / "actual_brightness").write_text("82\n")
    writes = stage / "writes"
    writes.touch()
    failure = stage / "failure"
    failure.touch()
    runtime = stage / "runtime"
    runtime.mkdir(mode=0o700)
    binaries = stage / "bin"
    binaries.mkdir()
    mock = binaries / "brightnessctl"
    mock.write_text('''#!/usr/bin/env python3
import os, pathlib, sys, time
root = pathlib.Path(os.environ["TEST_BACKLIGHT"]) / "mock"
if "info" in sys.argv:
    print("mock,backlight," + (root / "brightness").read_text().strip() + ",100%,100")
elif "set" in sys.argv:
    time.sleep(0.12)
    if pathlib.Path(os.environ["TEST_FAILURE"]).read_text():
        print("mock write denied", file=sys.stderr)
        sys.exit(1)
    value = sys.argv[-1]
    (root / "brightness").write_text(value + "\\n")
    with open(os.environ["TEST_WRITES"], "a") as log:
        log.write(value + "\\n")
''')
    mock.chmod(0o755)
    notify = binaries / "notify-send"
    notify.write_text("#!/bin/sh\nexit 0\n")
    notify.chmod(0o755)
    for name in ("BrightnessService.qml", "BrightnessSlider.qml", "SliderRow.qml", "Colors.qml"):
        text = (ROOT / "components" / name).read_text()
        if name == "BrightnessService.qml":
            text = text.replace('"/sys/class/backlight/"', f'"{backlight.parent}/"')
        (profile / name).write_text(text)
    theme = (ROOT / "profiles" / "default" / "Theme.qml").read_text()
    theme = "\n".join(line for line in theme.splitlines()
                      if line != "import Quickshell" and "sysmonPath:" not in line)
    (profile / "Theme.qml").write_text(theme)
    (profile / "qmldir").write_text("singleton Theme 1.0 Theme.qml\nsingleton Colors 1.0 Colors.qml\nsingleton BrightnessService 1.0 BrightnessService.qml\nSliderRow 1.0 SliderRow.qml\nBrightnessSlider 1.0 BrightnessSlider.qml\n")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=str(runtime),
               TEST_BACKLIGHT=str(backlight.parent), TEST_WRITES=str(writes),
               TEST_FAILURE=str(failure), PATH=str(binaries) + os.pathsep + os.environ["PATH"])
    env.pop("WAYLAND_DISPLAY", None)
    shutil.copyfile(ROOT / "tests" / "brightness.qml", stage / "brightness.qml")
    run(["quickshell", "-p", str(stage / "brightness.qml")], env, "REGRESSION PASS: brightness")
    nmcli = binaries / "nmcli"
    nmcli.write_text('''#!/usr/bin/env python3
import sys, time
args = sys.argv[1:]
if "monitor" in args:
    time.sleep(20)
elif "connect" in args:
    if "--ask" in args:
        assert sys.stdin.read() == "test-password\\n"
    time.sleep(0.1)
elif "disconnect" in args:
    assert args[-1] == "wlan1", args
elif args == ["radio", "wifi"]:
    print("enabled")
elif "ACTIVE,SSID,SIGNAL" in args:
    print("yes:active:10")
elif "TYPE,STATE,DEVICE" in args:
    print("wifi:disconnected:wlan0\\nwifi:connected:wlan1")
elif "SSID,SIGNAL,SECURITY,ACTIVE" in args:
    print("__proto__:90:WPA2:no\\nconstructor:80:WPA2:no\\n spaced :70::no\\nactive:10:WPA2:yes")
''')
    nmcli.chmod(0o755)
    for name in ("NetworkService.qml", "NotificationDaemon.qml", "NotificationPopup.qml"):
        text = (ROOT / "components" / name).read_text()
        if name == "NotificationPopup.qml":
            # Offscreen Qt has no layer-shell backend. Exercise the real popup
            # state machine and layout using a Rectangle as its window host.
            text = text.replace("PanelWindow {", "Rectangle {", 1)
            text = re.sub(r"    anchors \{.*?\n    \}", "", text, count=1, flags=re.S)
            text = re.sub(r"    margins \{.*?\n    \}", "", text, count=1, flags=re.S)
        (profile / name).write_text(text)
    with (profile / "qmldir").open("a") as module:
        module.write("singleton NetworkService 1.0 NetworkService.qml\n"
                     "singleton NotificationDaemon 1.0 NotificationDaemon.qml\n"
                     "NotificationPopup 1.0 NotificationPopup.qml\n")
    for name in ("BatteryIndicator.qml", "ControlPanel.qml", "MusicWidget.qml", "Divider.qml", "VDivider.qml", "VolumeSlider.qml", "SystemResourceRow.qml", "WifiToggle.qml", "BluetoothToggle.qml", "BluetoothService.qml"):
        text = (ROOT / "components" / name).read_text()
        if name == "BatteryIndicator.qml":
            text = text.replace("readonly property var device: UPower.displayDevice", "property var device: null")
        if name == "ControlPanel.qml":
            text = text.replace("PanelWindow {", "Rectangle {", 1)
            text = re.sub(r"    WlrLayershell.keyboardFocus:.*", "", text)
            text = re.sub(r"    anchors \{.*?\n    \}", "", text, count=1, flags=re.S)
            text = re.sub(r"    mask: Region \{.*?\n    \}", "", text, count=1, flags=re.S)
        (profile / name).write_text(text)
        prefix = "singleton " if name == "BluetoothService.qml" else ""
        with (profile / "qmldir").open("a") as module:
            module.write(f"{prefix}{Path(name).stem} 1.0 {name}\n")
    for name, script in {"busctl": "echo '{\"data\":[{}]}'", "dbus-monitor": "sleep 20", "playerctl": "exit 0"}.items():
        executable = binaries / name
        executable.write_text("#!/bin/sh\n" + script + "\n")
        executable.chmod(0o755)
    module_text = (profile / "qmldir").read_text()
    shutil.copyfile(ROOT / "tests" / "services.qml", stage / "services.qml")
    slider_test = (ROOT / "tests" / "tst_slider.qml").read_text().replace('"../profiles/default"', '"profile"')
    (stage / "tst_slider.qml").write_text(slider_test)
    for theme_name in ("default", "alt"):
        print(f"Testing {theme_name} theme", flush=True)
        theme = (ROOT / "profiles" / theme_name / "Theme.qml").read_text()
        theme = "\n".join(line for line in theme.splitlines()
                          if line != "import Quickshell" and "sysmonPath:" not in line)
        theme = theme.replace("QtObject {", 'QtObject {\n readonly property string sysmonPath: "' + str(ROOT / "native/sysmon") + '"', 1)
        (profile / "Theme.qml").write_text(theme)
        (profile / "qmldir").write_text(module_text)
        run(["quickshell", "-p", str(stage / "services.qml")], env, "REGRESSION PASS: services")
        # Qt's standalone runner cannot load Quickshell's executable plugins.
        # Use the actual slider with just its two visual singletons.
        (profile / "qmldir").write_text("singleton Theme 1.0 Theme.qml\nsingleton Colors 1.0 Colors.qml\n")
        run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(stage / "tst_slider.qml")], env)

# Keyboard focus regression uses a standalone, isolated Qt scene.
subprocess.run(["python3", str(ROOT / "tests/focus.py")], check=True)
