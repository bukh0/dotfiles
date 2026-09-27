#!/usr/bin/env bash
set -u
source "$(dirname "$0")/quickshell-common.sh"

CURRENT_BAR="$(quickshell_read_bar)"
[[ "$CURRENT_BAR" == "default" || "$CURRENT_BAR" == "alt" ]] || CURRENT_BAR="default"

if pgrep -x quickshell >/dev/null; then
    quickshell_stop
    for _ in {1..30}; do
        pgrep -x quickshell >/dev/null || break
        sleep 0.1
    done
fi

quickshell_stop_notification_daemons
quickshell_start "$CURRENT_BAR" || exit 1
quickshell_write_bar "$CURRENT_BAR"
