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
tests/               Regression runner and shared Python helpers
tests/bluetooth/     Bluetooth profile and transport state
tests/network/       Status recovery and monitor event bursts
tests/picker/        Operation exit and collector handling
tests/integration/   Isolated startup and reload checks
```

Use `./run.sh` for the default profile and `./run.sh alt` for the alternate profile. `native/Makefile` builds `native/sysmon`; both profiles resolve the helper from there.

Sensor discovery starts with the shell; resource sampling still runs only while
the control panel is open. Cached CPU/network readings remain visible until a
fresh measurement interval is available.

Music state lives in `MusicService.qml` and updates through native MPRIS signals. Closing the control panel releases its widgets while retaining the music model. `SysmonService.qml` samples only while resource rows are loaded, retaining its last values between panel openings. The custom power toggle is retained because it controls both auto-cpufreq and AMD GPU settings.

Bluetooth pairing uses the installed Blueman dialogs through `native/bluetooth_pair.py`
(Python 3, PyGObject, GTK 3, and Blueman). The helper registers an agent only for
its own pairing request and exits afterwards; it does not start a persistent
applet or replace the session's default agent. PIN and confirmation dialogs
remain available with Do Not Disturb enabled. The helper is tested with Blueman
2.4.6 and uses its private dialog/path APIs; check pairing with a device after
Blueman upgrades. Cancellation is scheduled before the Pair call deadline.

`~/.scripts/picker-menu.sh` builds the theme helper on demand. All theme application goes through `theme.switcher --apply THEME [WALLPAPER]`; `wallpick.sh` remains a compatibility wrapper. The helper uses OpenSSL for cache hashes and `vipsthumbnail` for previews. Generated binaries and dependency files are ignored by Git.

Run `python3 tests/run.py` (or `python3 tests/run.py --all`)
for all available isolated suites, or `python3 tests/run.py --list` to list
individual suites. Suite names stay the same regardless of their subdirectory;
use the runner so shared helpers are available. Clipboard tests in `clipboard/tests/test_*.py` are discovered
as `clipboard_*` suites. Pass suite names to run a subset, for example
`python3 tests/run.py clipboard_ui monitor_burst process_results startup`.
The runner disables Python
bytecode generation so tests do not leave cache folders in the configuration. Tests require Quickshell,
Qt 6 test tools and the relevant native helper dependencies. The local
`.pre-commit-config.yaml` targets the parent dotfiles checkout. From `~/dotfiles`,
install it with `pre-commit install --config quickshell/.pre-commit-config.yaml`
and run it with `pre-commit run --config quickshell/.pre-commit-config.yaml --all-files`.

The deployed configuration is backed by the existing `quickshell/` directory in
`~/dotfiles`; this directory need not be a separate Git repository. Bluetooth
profile and network status fixtures were restored from that tracked copy.

Desktop integration suites that need external files under `~/.scripts`,
`~/dotfiles`, or the desktop config explicitly skip when those inputs are
missing. The runner lists these skips separately from passing suites. Existing
test path overrides still work; missing external files do not establish that
the corresponding integration passes. Available but broken scripts still fail.

Volume supports adjustment up to 150%. Higher externally set values remain
visible and can be reduced without an abrupt jump to 100%.

Colors update live from `components/colors.json`; changing a theme no longer
reloads the shell. The theme writer, Matugen and Pywal templates, and preset
palettes all use JSON.

Notification windows are thin `PanelWindow` wrappers around
`NotificationPopupContent.qml` and `NotificationDrawerContent.qml`.
Explicit web and mail links are clickable, and a
popup body click invokes its default action when available. Opening the notification
panel clears active and queued popups without deleting history; popups resume
for new arrivals after the panel closes. History survives hot reloads but is not saved across process restarts.

After Quickshell upgrades, check notification timeouts/restoration, workspace
switching and panel input regions in the running session. The available isolated
suites do not cover compositor surfaces or hardware operations. Earlier
notification, profile-load and Wayland test files are absent from this checkout.

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
