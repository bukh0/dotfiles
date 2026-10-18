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

Run `python3 tests/run.py`, `python3 tests/launcher.py`, `python3 tests/picker.py`, and `python3 tests/theme.py` for the main regressions. Clipboard tests are in `clipboard/tests/`. The theme suite includes a 1,600-image queue stress test with a mock thumbnailer; it uses temporary directories and mock desktop commands.

Notification windows are thin `PanelWindow` wrappers around
`NotificationPopupContent.qml` and `NotificationDrawerContent.qml`. Tests load
these content items directly. Explicit web and mail links are clickable, and a
popup body click invokes its default action when available. History survives
hot reloads but is not saved across process restarts.

After Quickshell upgrades, run `python3 tests/notifications.py` and
`python3 tests/notification_reload.py` to check timeout units and notification
restoration. The installed 0.3.2 build exposes `expireTimeout` in milliseconds.
Run `python3 tests/input_edges.py` for workspace dispatch branches; it mocks
`Hyprland.usingLua`, so also check workspace switching in the running session.

For the notification and lifecycle changes, run `notification_state.py`,
`notification_layout.py`, `popup_stack.py`, `notification_body.py`,
`palette_reload.py`, and `sysmon_launch.py` from `tests/`. Set
`QS_TEST_PROFILE=alt` for alternate-profile state/layout checks.
`python3 tests/profile_load.py` loads both actual window wrappers invisibly on
Wayland using a private D-Bus session; it does not replace the running shell.

To inspect the floating bar's real Wayland input region, run
`QS_TEST_BAR_MASK=1 python3 tests/profile_load.py`. This briefly shows the test
bar without reserving screen space or moving the pointer, and checks that bell
and clock hit extensions are included while unrelated margins remain excluded.
