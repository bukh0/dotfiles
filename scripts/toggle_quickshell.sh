#!/usr/bin/env bash
set -u
source "$(dirname "$0")/quickshell-common.sh"

CURRENT_BAR="$(quickshell_read_bar)"
[[ "$CURRENT_BAR" == "default" || "$CURRENT_BAR" == "alt" ]] || CURRENT_BAR="default"
quickshell_write_bar "$CURRENT_BAR"

if pgrep -x quickshell >/dev/null; then
    quickshell_stop
else
    quickshell_stop_notification_daemons
    quickshell_start "$CURRENT_BAR"
fi
