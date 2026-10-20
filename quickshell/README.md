# Quickshell configuration

The bar has two launch profiles, `default` and `alt`. Shared visual tokens live in `components/BaseTheme.qml`. Each profile has a small `Theme.qml` and `qmldir`; its QML component links point to the shared implementations. The `alt` theme overrides the floating bar and rounded control dimensions.

```text
components/          Shared QML components and shell root
profiles/default/    Default profile theme and module entry points
profiles/alt/        Alternate profile theme and module entry points
native/              sysmon source/build and on-demand Bluetooth pairing helper
picker/              Theme and wallpaper picker
clipboard/           Clipboard browser and byte-safe Python bridge
run.sh               Profile launcher (`run.sh [default|alt]`)
reload.sh            Launcher alias
tests/               Isolated regression fixtures
docs/reviews/        Historical review notes
```

Use `./run.sh` for the default profile and `./run.sh alt` for the alternate profile. `native/Makefile` builds `native/sysmon`; both profiles resolve the helper from there.

Music state lives in `MusicService.qml` and updates through native MPRIS signals. Closing the control panel releases its widgets while retaining the music model. `SysmonService.qml` samples only while resource rows are loaded, retaining its last values between panel openings. The custom power toggle is retained because it controls both auto-cpufreq and AMD GPU settings.

Bluetooth pairing uses the installed Blueman dialogs through `native/bluetooth_pair.py`
(Python 3, PyGObject, GTK 3, and Blueman). The helper registers an agent only for
its own pairing request and exits afterwards; it does not start a persistent
applet or replace the session's default agent. PIN and confirmation dialogs
remain available with Do Not Disturb enabled.

`~/.scripts/picker-menu.sh` builds the theme helper on demand. All theme application goes through `theme.switcher --apply THEME [WALLPAPER]`; `wallpick.sh` remains a compatibility wrapper. The helper uses OpenSSL for cache hashes and `vipsthumbnail` for previews. Generated binaries and dependency files are ignored by Git.

Run `python3 tests/run.py` for core regressions, `python3 tests/run.py --all`
for all discovered isolated suites, or `python3 tests/run.py --list` to list
individual suites. Pass suite names to run a subset. Tests require Quickshell,
Qt 6 test tools and the relevant native helper dependencies. The local
`.pre-commit-config.yaml` runs the core suite when installed in a Git checkout.

Colors update live from `components/colors.json`; changing a theme no longer
reloads the shell. The theme writer, Matugen and Pywal templates, and preset
palettes all use JSON. Notification restoration is still needed for code reloads.

Notification windows are thin `PanelWindow` wrappers around
`NotificationPopupContent.qml` and `NotificationDrawerContent.qml`. Tests load
these content items directly. Explicit web and mail links are clickable, and a
popup body click invokes its default action when available. Opening the notification
panel clears active and queued popups without deleting history; popups resume
for new arrivals after the panel closes. History survives
hot reloads but is not saved across process restarts.

After Quickshell upgrades, run `python3 tests/notifications.py` and
`python3 tests/notification_reload.py` to check timeout units and notification
restoration. The installed 0.3.2 build exposes `expireTimeout` in milliseconds.
Run `python3 tests/input_edges.py` for workspace dispatch branches; it mocks
`Hyprland.usingLua`, so also check workspace switching in the running session.

Set `QS_TEST_PROFILE=alt` for alternate-profile notification state/layout checks.
`python3 tests/run.py --live profile_load wayland_surfaces` tests the actual
window wrappers and Wayland surfaces on a private D-Bus session. The latter
briefly shows a tooltip and pins a test panel to check keyboard-focus delivery.

To inspect the floating bar's real input region, run
`QS_TEST_BAR_MASK=1 python3 tests/run.py --live profile_load`. This briefly shows
a test bar without reserving screen space or moving the pointer.

Super+F maximizes while keeping the bar visible. Super+Shift+F enters fullscreen
and hides only that monitor's bar and notification drawer. Manual bar visibility
remains independent.
