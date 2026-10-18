# Follow-up bug review — 2026-10-08

Scope: notification popup/daemon, shell visibility and bar scripts, power-profile
changes, plus targeted reads of control-panel, brightness, Bluetooth, network and
clipboard services. This was a focused review, not a claim of exhaustive coverage.
No production configuration or scripts were changed during this review.

## Findings

1. **Hot reload replays history as new popups and resets arrival timestamps.**
   NotificationDaemon.qml:184 and :238 process re-emitted tracked notifications
   exactly like new arrivals. In the private D-Bus test, two received notifications
   produced two popup signals before reload and two more afterward; both stored
   timestamps changed. History restoration itself works (the previous review was
   correct on that narrower point). A theme-triggered reload can therefore bring
   back alerts the user already hid. Recognize last-generation restoration,
   suppress popup emission for it, and preserve original timestamps across reload.

2. **Fullscreen suppression can leave all bars hidden.**
   shell.qml:13 stores fullscreen in PersistentProperties; :21 changes it only
   through IPC; :78 gates every bar on it. fullscreen_toggle.sh sends a one-time
   snapshot. There is no subscription clearing the value when the window leaves
   fullscreen, closes, or changes workspace. Once set, bar.show and bar.toggle
   cannot override it, and hot reload preserves it. Verified by source tracing,
   not by changing the live compositor. Track fullscreen from compositor events
   on the relevant monitor rather than persisting a global one-time snapshot.

3. **Fast repeated dismissals only dismiss one popup.**
   NotificationPopup.qml:89 always selects active[0]. That item stays in the
   model during its 220 ms fade, and :120 ignores another beginClose call.
   Reproduced: three persistent cards, three dismiss calls 30 ms apart, two cards
   remain. Select the newest card that is not already closing.

4. **A single queued notification dismisses all persistent cards.**
   NotificationPopup.qml:125–144 independently starts every persistent card's
   yield timer when queueCount becomes positive. With three persistent cards and
   one queued card, all timers fire before the first removal/refill completes.
   Reproduced: after yielding, only the queued card remains instead of three
   visible cards. Coordinate yielding so only the needed number of slots closes.

Findings 2–4 are regressions in the recent stack/bar changes. Existing tests
covered single-slot yielding and single dismissals, but not these combinations.

## Evidence

- /tmp/qs-review-oct08/popups.py: existing popup input tests plus two added cases;
  eight cases passed, the two new cases failed as described above.
- /tmp/qs-review-oct08/reload.py: actual Quickshell on private D-Bus with isolated
  cache; popup count rose from 2 to 4 across reload and both timestamps changed.
- The offscreen reload-overlay warning is a test-environment limitation, not one
  of the reported bugs.
- Fullscreen finding is conditional on invoking the helper while fullscreen;
  live fullscreen, power and audio state were not modified.


## Fixes applied

All four findings are fixed. Popup closing state is now stored in the model:
repeated dismissals skip closing cards, and persistent yielding reserves only as
many slots as the queue needs. Normal timeouts, critical preemption and updates
during fading retain their behavior.

Bar visibility follows each monitor's active workspace hasFullscreen property.
Only manual visibility is persisted. The old setFullscreen IPC method remains
compatible with existing scripts, but refreshes compositor state instead of
saving their one-time boolean. No polling was added.

Notification restoration suppresses popups and restores primitive timestamp
metadata from shell-owned PersistentProperties. The installed reload mechanism
did not restore PersistentProperties nested in the singleton, so the state lives
at shell scope. Real app replacements are distinguished from restoration. The
extended test also exposed that Quickshell mutates an existing Notification
without emitting onNotification on replacement; coalesced property-change
handling now updates its history row and popup.

Validation: popup_stack.py (10 cases), bar_visibility.py (6 cases), both profiles
in tests/run.py, private-D-Bus notifications.py, and notification_reload.py across
two reloads, including a real replacement, critical/DND restoration and cleanup.
The running bar automatically hot-reloaded; its latest load completed without
QML errors. No live fullscreen, audio, or power changes were used for testing.

Relevant implementation references checked during verification:
- https://github.com/quickshell-mirror/quickshell/blob/master/src/services/notifications/server.cpp
- https://github.com/quickshell-mirror/quickshell/blob/master/src/core/persistentprops.cpp
