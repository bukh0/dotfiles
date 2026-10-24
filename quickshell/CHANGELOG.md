# Changelog

## 2026-10-24 — feature add-ons removed

At the user's request, removed native network/Bluetooth status, disk notification
history, the added panel/drawer/clearAll IPC commands, battery alerts/tooltips and
animation, and music position/seeking. Restored the command-backed status paths
and the existing battery indicator behavior, retaining its PendingCharge fix.
Existing history files are left untouched but are no longer read or written.
Bug fixes, picker timeout/cancellation, shared theme/module definitions and the
regression hook remain. Fullscreen behavior is unchanged.

Follow-up review: network and tray tooltips now explicitly render plain text;
DND writes are atomic. DND retains its existing cache location for compatibility.
The picker accepts a late initial focused-monitor update without following later
focus changes, covered by picker_screen.py. Passive tray items are hidden.
Removed the redundant completed-work checkpoint. Native RSSI/startup notification,
disk-history privacy and alert-threshold reports no longer apply after removal.
No new mic/calendar/power-menu or authorization-policy features were added.
The volume track intentionally expands above 150% to permit reducing an externally
set value without an abrupt clamp; no scale change was made. Link confirmation
and OnDemand panel focus would change interaction behavior and were not added
without a reproduced failure. The existing five-minute brightness retry remains:
a finite retry budget without a working hotplug subscription would prevent later
backlight discovery. Tooltip sharing and a state-directory migration for DND are
separate refactors, not part of this feature rollback.

## 2026-10-24 — original changes (feature removals above supersede these)

- Abort volume gestures when the default sink changes, including subsequent
  pointer movement and release. Disabled volume now reads 0% without a sink.
- Cancel the owning output's Wi-Fi password prompt on panel destruction.
- Move the October 22 reproductions into test discovery. Identical notification
  replacement remains an upstream limitation: the installed Quickshell build
  emits neither a property change nor a notification event for an identical
  payload. `notification_identical.py` reports this expected limitation and will
  report PASS when the API delivers the event. No polling workaround was added.
- Read network and Bluetooth status from native Quickshell modules. Normal
  operation no longer runs nmcli/dbus-monitor status monitors or periodic status
  subprocesses. Keep command transports for Wi-Fi scan/connect and Bluetooth
  actions/pairing. Legacy status code remains available for transport regression
  fixtures and diagnostics via `nativeStatusEnabled: false`.
- Bound picker apply operations to 45 seconds, terminating remaining children
  after a two-second grace period. Escape cancels an operation and returns an
  error; cancellation cannot undo changes already applied. GNU coreutils timeout
  is required. Handle cancellation while a process is still starting.
- Debounce atomic notification-history writes to
  `$XDG_STATE_HOME/quickshell/notifications.json` (default `~/.local/state`).
  Restore at most 50 rows as history-only entries, without actions or popup
  replay. Merge re-delivered live notifications with archived rows on reload.
  Create new state directories with owner-only access.
- Add focused-output IPC: `controlpanel toggle`, `drawer toggle`, and
  `notifications clearAll`. Existing bar visibility/fullscreen behavior remains
  unchanged.
- Notify once at 15% and 5% per battery discharge cycle; retain alert flags across
  shell reloads. Charging or recovery above 20% resets the cycle. Show estimated
  charge/discharge time and power draw in a separate tooltip window. Replace the
  icon's flashing timer with an opacity animation.
- Add MPRIS position/duration and seeking. Refresh position once per second only
  for the visible playing page. Reject an old seek gesture after a track change.
- Display sudo's actual prompt in the power-profile password dialog.
- Share sysmonPath through BaseTheme and both profile module lists through
  `profiles/qmldir` symlinks, avoiding generated-file writes at startup.
- Install the dotfiles regression hook and root pre-commit configuration link.
  The direct Git hook works without the optional pre-commit package.
- Consolidate dated review notes here and remove obsolete repro bytecode.
  Tests cover sink replacement, panel ownership, native status subscriptions,
  disk history, threshold crossings, seek gestures and picker cancellation.

Validation: all 50 isolated suites passed, with the documented upstream
identical-replacement XFAIL. Both profiles also passed actual Wayland wrapper
load checks. Fullscreen regression checks passed without changing that logic.

Wi-Fi authentication follow-up: upstream nmcli looks for a matching profile and
uses a secret agent during activation. Source inspection alone does not prove
that an incorrect-password attempt followed by a correct password works with
this machine's access point. No live authentication experiment or automatic
profile deletion was performed. See the
[NetworkManager implementation](https://github.com/NetworkManager/NetworkManager/blob/main/src/nmcli/devices.c).

## 2026-10-22

- Collapse the Wi-Fi list on an external radio-off event, also cancelling its
  password prompt. Reopening the list after radio-on starts discovery normally.
- Use separate tooltip windows for notification buttons and show the actual
  destination of notification links on hover. Tooltip content is plain text.
- Merge notification timestamps restored after server re-delivery, repair row
  timestamps and ordering, and preserve real arrivals/replacements. Delay writes
  to persistent history until its saved values have loaded.
- Correct pre-commit paths for the parent dotfiles repository and document the
  explicit nested-config installation command (superseded by the root hook below).
- Keep C++ language/warning flags when callers supply CXXFLAGS; callers can still
  deliberately override optimization for debug builds.
- Locate the power-profile regression's Process by ID instead of its position
  before the CPU property.
- Fullscreen behavior is unchanged.

Current panel/drawer hover-close delay is 510 ms. Sysmon uses RAM,
temperature and profile values immediately, skipping only the first CPU/network
delta sample after starting.

### Edge-case follow-up

- Migrated resource-row and picker tooltips to separate popup windows. Plain-text
  rendering belongs on a `Text` content item, not on `ToolTip` itself; corrected
  the previous notification tooltip implementation too. A picker load regression
  caught the unsupported property before this follow-up was completed.
- Preserve unquoted HTTP(S)/mailto notification links while retaining URL and
  attribute validation.
- Reapply the popup window's target monitor at the start of each new burst,
  including when content still remembers that same monitor. Existing queued
  bursts retain their screen. The alleged zero-capacity queue case is excluded
  by the existing minimum capacity of one.
- Consume sysmon's temperature-restart intent on exit and clear it when idle.
  The existing launch timer already cleared it before restarting; the claimed
  later-crash backoff failure was not established through the normal start path.
- Settle Bluetooth polls only after exit and stdout completion. Failed launches
  have a watchdog, cannot reuse old output, and drain queued refreshes. Nonzero
  exits mark the service unavailable even if stdout contains valid old data.
- Reopen the temperature node each sample to recover from unavailable or replaced
  nodes. Trim profile-state whitespace and sanitize CPU model record delimiters.
  Interface names are not emitted in the record, so no interface-output escape
  is needed. Existing buffered `/proc` read regressions pass without replacing
  `seekg` with lower-level seeking.
- Route workspace clicks through the same Lua-aware dispatch as scrolling and
  focus the clicked bar's monitor first. Workspace IDs remain global; this does
  not move an existing workspace to another monitor.
- Wait for a bounded CancelPairing call before helper shutdown. The fake BlueZ
  regression verifies cancellation arrives before agent unregistration.
- Expand the picker's dismissal-mask hole to cover both current and requested
  sizes during a resize.

The drawer measurement loop is bounded to 50 rows and has no demonstrated
performance defect; it remains unchanged. `native/*.d`, `__pycache__/`, and
`*.pyc` are already ignored. An explicit `git add -f` overrides ignore rules;
adding more ignore patterns cannot prevent that.

Follow-up validation: native build; core (both themes); picker;
notification_body/state; popup_stack (including wrapper screen reset);
input_edges (real clicks in both dispatch modes); workspaces; bar_visibility;
Bluetooth devices/action/poll tests; pairing cancellation on private fake BlueZ;
sysmon launch, profile, sampling and temperature-node replacement tests.
Actual monitor unplugging and visual Wayland tooltip placement were not tested.

### Review dispositions

- Leading-dash SSIDs: no command change. NetworkManager's `do_device_wifi_connect`
  consumes the first argument as SSID/BSSID before parsing connection options.
  See [the upstream parser](https://github.com/NetworkManager/NetworkManager/blob/main/src/nmcli/devices.c).
- Password length: no blanket restriction. This prompt does not distinguish WPA
  passphrases from other supported credentials, including raw PSKs and WEP keys.
- Font enumeration: BaseTheme's property is evaluated per theme instance, not
  per frame or panel opening. No measured startup regression was established.
- Fixed test delays and Blueman private APIs remain maintenance risks; this
  change does not claim to eliminate them.
- IPC, native read-only status, battery alerts/tooltips and restart history were
  subsequently implemented on October 24. Configurable workspace/tray/clock
  constants and drawer-height animation remain optional improvements.

Validation: core (both profiles), focus, music_sync, network_cancel,
notification_state (including late restoration and replacement),
notification_reload, notification_layout, notification_body, profile_exit and
bar_visibility. The reload regression needs permission to create a private D-Bus
socket; it passed outside the filesystem sandbox. Compiler command generation
was checked with an explicit CXXFLAGS override. Tooltip positioning has not been
visually checked on the live desktop.

## Consolidated history: September 28 – October 21, 2026

These entries replace the dated review reports; they describe the resulting
behavior rather than superseded intermediate test counts or timings.

- Shared components, profile themes and native sources were separated. Brightness
  reads the same setpoint it writes, coalesces writes, retries transient read
  failures and rediscovers missing devices. Sysmon runs only with visible
  watchers, uses bounded crash backoff and rediscovers temperature sensors.
- Process-backed actions wait for exit and collector completion, reject stale
  output after failed startup and use launch/watchdog timers. Intentional idle
  shutdown is distinct from a crash. Power-profile cancellation distinguishes
  cancellation before any privileged success from a partial change or error.
- Notification stacks gained bounded slots/queues, critical preemption,
  hover-paused timeouts, DND handling, links/default actions and stable reload
  timestamps. Opening the drawer clears popups without deleting history. Drawer
  measurement caches invalidate on row updates, and scrolling caps queued travel.
- Floating-bar masks and control-panel focus/hover ownership were corrected.
  Password prompts are output-scoped; saved/open-network connections remain
  hover-only. Hidden bars cancel delayed hover opens. Music uses native MPRIS,
  filters playerctld, and reconciles its model before publishing the selected
  index. Wheel/page handoffs respect overflowing panels.
- Picker listing and thumbnail work coalesces refreshes and handles missing
  helpers and late completion. Wheel/touchpad scrolling uses configured easing,
  bounded queued travel and immediate reversal. Keyboard reveal follows layout.
- Clipboard work preserved binary data and MIME types, bounded preview work,
  skipped sensitive offers and handled paste/helper failures. External theme
  helpers gained shared application locking, atomic file writes and consistent
  entry points; multi-file rollback remains outside this configuration.

Remaining integration limits: hidden-network and new enterprise Wi-Fi setup,
per-monitor DDC brightness and compositor-specific title-blanking behavior are
not implemented or established fixes. Blueman pairing depends on private APIs;
rerun its fake-BlueZ test after upgrades. Physical Wi-Fi authentication, monitor
unplugging, battery discharge and reboot/login behavior need hardware/session
checks; isolated fixtures do not establish those outcomes. Historical external
WayClick cleanup, fresh-install restore and wallpaper-parent containment leads
were not re-audited in this change.
