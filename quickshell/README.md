# Quickshell configuration

See [CHANGELOG.md](CHANGELOG.md) for current changes and review dispositions.

The bar has two launch profiles, `default` and `alt`. Shared visual tokens live in `components/BaseTheme.qml`. Each profile has a small `Theme.qml` and links to the shared `profiles/qmldir`; its QML component links point to the shared implementations. The `alt` theme overrides the floating bar and rounded control dimensions.

```text
components/          Shared QML components and shell root
profiles/default/    Default profile theme and module entry points
profiles/alt/        Alternate profile theme and module entry points
native/              sysmon source/build and on-demand Bluetooth pairing helper
picker/              Theme and wallpaper picker
clipboard/           Clipboard browser and byte-safe Python bridge
run.sh               Profile launcher (`run.sh [default|alt]`)
reload.sh            Launcher alias
tests/               Python regression suites and runner
tests/fixtures/      QML fixtures staged by the core suite
```

Use `./run.sh` for the default profile and `./run.sh alt` for the alternate profile. `native/Makefile` builds `native/sysmon`; both profiles resolve the helper from there.

Music state lives in `MusicService.qml` and updates through native MPRIS signals. Closing the control panel releases its widgets while retaining the music model. `SysmonService.qml` samples only while resource rows are loaded, retaining its last values between panel openings. The custom power toggle is retained because it controls both auto-cpufreq and AMD GPU settings.

Bluetooth pairing uses the installed Blueman dialogs through `native/bluetooth_pair.py`
(Python 3, PyGObject, GTK 3, and Blueman). The helper registers an agent only for
its own pairing request and exits afterwards; it does not start a persistent
applet or replace the session's default agent. PIN and confirmation dialogs
remain available with Do Not Disturb enabled. The helper is tested with Blueman
2.4.6 and uses its private dialog/path APIs; rerun `tests/bluetooth_pair.py`
after Blueman upgrades. Cancellation is scheduled before the Pair call deadline.

`~/.scripts/picker-menu.sh` builds the theme helper on demand. All theme application goes through `theme.switcher --apply THEME [WALLPAPER]`; `wallpick.sh` remains a compatibility wrapper. The helper uses OpenSSL for cache hashes and `vipsthumbnail` for previews. Generated binaries and dependency files are ignored by Git.

Run `python3 tests/run.py` for core regressions, `python3 tests/run.py --all`
for all discovered isolated suites, or `python3 tests/run.py --list` to list
individual suites. Clipboard tests in `clipboard/tests/test_*.py` are discovered
as `clipboard_*` suites; backend, service and UI checks also run by default. Both
commit-hook filters include `clipboard/`. Pass suite names to run a subset. The runner disables Python
bytecode generation so tests do not leave cache folders in the configuration. Tests require Quickshell,
Qt 6 test tools and the relevant native helper dependencies. The local
`.pre-commit-config.yaml` targets the parent dotfiles checkout. From `~/dotfiles`,
install it with `pre-commit install --config quickshell/.pre-commit-config.yaml`
and run it with `pre-commit run --config quickshell/.pre-commit-config.yaml --all-files`.
The checkout also provides a direct Git hook (`quickshell/tests/pre-commit`)
for installations without the optional pre-commit package. It is installed in
this dotfiles checkout; to install it in a fresh clone, run
`ln -s ../../quickshell/tests/pre-commit .git/hooks/pre-commit` from the repo root
when no pre-commit hook already exists.
Its commands and file filters are relative to that repository root.

The deployed configuration is backed by the existing `quickshell/` directory in
`~/dotfiles`; this directory need not be a separate Git repository. The local
`tests/` fixtures were restored from that tracked copy.

Volume supports adjustment up to 150%. Higher externally set values remain
visible and can be reduced without an abrupt jump to 100%.

Colors update live from `components/colors.json`; changing a theme no longer
reloads the shell. The theme writer, Matugen and Pywal templates, and preset
palettes all use JSON.

Notification windows are thin `PanelWindow` wrappers around
`NotificationPopupContent.qml` and `NotificationDrawerContent.qml`. Tests load
these content items directly. Explicit web and mail links are clickable, and a
popup body click invokes its default action when available. Opening the notification
panel clears active and queued popups without deleting history; popups resume
for new arrivals after the panel closes. History survives hot reloads but is not saved across process restarts.

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

External helper locations can be overridden with `QS_THEME_SWITCHER` (picker
executable), `QS_PERFORMANCE_SCRIPT` (power-profile shell script), and
`QS_QUICKSHELL_COMMON` (notification wrapper's shared shell library). Defaults
remain under `~/.scripts`; set overrides in the environment that launches the
shell or wrapper.

The picker requires GNU coreutils `timeout`. Theme/wallpaper application times out
after 45 seconds; Escape cancels the process group. Cancellation reports that
partial changes may already have been applied.
