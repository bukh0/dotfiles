Review completed on 2026-09-28. Changes are in `shared/`, so both `default` and `alt` receive them through their existing symlinks.

| Area | Finding and implemented fix |
| --- | --- |
| Brightness readback | The service wrote `brightness` but read `actual_brightness`. On this AMD backlight, the initial readings were 65535 and 53434 respectively, with a maximum of 65535. Readback now uses the same setpoint that brightnessctl writes. |
| Brightness writes | Drag events could start a process for nearly every pointer update. Writes now coalesce over 40 ms, remain serialized, and preserve the latest pending request. |
| Brightness recovery | Added non-finite input rejection, a shared hardware-rounded 1% minimum, exit/start failure handling, and device rediscovery after read failure. Failed writes reconcile with the device and can be retried. |
| Multiple brightness widgets | A destroyed widget could clear the global dragging flag while another widget was dragging. Interaction ownership is now counted per widget. |
| Slider behavior | Corrected pointer-to-thumb mapping, release/cancel state, and layout height. Reserved label space prevents the track changing width at 100%. |
| Volume | Disabled the control without an audio sink and canceled deferred volume writes when the sink changes. |
| Battery | Removed a second division by 100 and hid the indicator when a battery is absent or not ready. Quickshell already exposes charge as a fraction; see the [upstream conversion](https://github.com/quickshell-mirror/quickshell/blob/master/src/services/upower/device.cpp). |
| Wi-Fi operation state | Moved busy/target state and error reporting into the persistent service. Closing a panel no longer loses operation state or errors, and radio commands cannot race with connection attempts. |
| Wi-Fi connection | Bounded connection waiting, closed password input after writing it, cleared the field after submission, and handled failure to launch. Disconnect now targets a connected Wi-Fi interface instead of blindly choosing the first adapter. |
| Wi-Fi discovery | Preserved SSID whitespace, handled names such as `constructor` and `__proto__`, recognized empty security fields as open networks, prioritized the active network, kept results visible during refresh, and fixed scan completion/queued refresh handling. |
| Notifications | Removed closed notifications from the visible popup and its queue. Replacements update existing popups/queue entries, without repeatedly connecting the same close signal. Persistent/critical popups no longer acquire an automatic timeout. |
| Notification presentation | Removed the mouse overlay that intercepted child controls, displayed summaries/app names as plain text, bounded popup summary length, corrected list scrolling after row removal, and separated popup screen selection from drawer screen selection. |
| Panel sizing | Expanded control panels now scroll within the available screen height. Drawer sizes also respect screen bounds. Hover-close scheduling respects pinned panels. |
| Music | Added a record delimiter so multiline metadata stays intact, cleared stale artwork when the track changes, and rendered titles/artists as plain text. |
| Bluetooth | Added a timeout to power commands so a hung bluetoothctl cannot lock the controls indefinitely. |
| System monitor | Zero available memory is valid; missing required memory fields are now distinguished from valid zero values. Rebuilt the helper. |
| Launcher | Validates profile entry files before stopping the shell, checks the executable, prepares directories before stopping, handles terminated zombie processes, and serializes concurrent reloads with flock. |

Validation performed:

- `qmllint -I /usr/lib/qt6/qml default/*.qml` and the equivalent for `alt`: no diagnostics.
- `python3 tests/run.py`: brightness state-machine tests; Wi-Fi, battery, notification, music, and panel regressions; and pointer interaction tests with both themes.
- `python3 tests/launcher.py`: invalid-profile handling and concurrent launches using a mock shell.
- `bash -n run.sh reload.sh`; C++ build with warnings enabled; three system-monitor output samples checked for field count and valid percentages.
- A read-only instance of the updated brightness service successfully discovered the real AMD backlight and read its current setpoint.

The tests use temporary fixtures and mock commands. Offscreen panel tests replace the layer-shell window host with a Rectangle, while preserving the component content and logic. Restricted-environment IPC, D-Bus, and PipeWire warnings are expected; those integrations are not exercised by the mocks. Actual brightness writes, network changes, Bluetooth pairing, and compositor input routing still need a desktop interaction check. The existing running shell was not deliberately restarted.

Remaining implementation opportunities include replacing playerctl polling with native MPRIS bindings and replacing the command-based network/Bluetooth services with native APIs. Those are larger architectural changes that need their own integration testing. Brightness still controls the backlight selected by brightnessctl; per-monitor DDC/CI control is not implemented.

Original configuration backup: `/tmp/quickshell-before-review.tar.gz`. Reload the desired profile with `./reload.sh default` or `./reload.sh alt`.
