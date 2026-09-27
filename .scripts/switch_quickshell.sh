#!/usr/bin/env bash
set -u
source "$(dirname "$0")/quickshell-common.sh"

CURRENT_BAR="$(quickshell_read_bar)"

if [[ "${1:-}" == "reload" ]]; then
    TARGET_BAR="$CURRENT_BAR"
else
    [[ "$CURRENT_BAR" == "default" ]] && TARGET_BAR="alt" || TARGET_BAR="default"
fi

if pgrep -x quickshell >/dev/null; then
    quickshell_stop
fi

# Wait for Quickshell to release its instance/socket before starting the
# replacement. A fixed short sleep is unreliable under load.
for _ in {1..30}; do
    pgrep -x quickshell >/dev/null || break
    sleep 0.1
done

if pgrep -x quickshell >/dev/null; then
    printf 'Could not stop the running Quickshell instance\n' >&2
    exit 1
fi

quickshell_stop_notification_daemons
if ! quickshell_start "$TARGET_BAR"; then
    printf 'Could not start Quickshell profile: %s\n' "$TARGET_BAR" >&2
    exit 1
fi
quickshell_write_bar "$TARGET_BAR"
