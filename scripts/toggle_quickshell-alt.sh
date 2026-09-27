#!/usr/bin/env bash
set -u
source "$(dirname "$0")/quickshell-common.sh"

if pgrep -x quickshell >/dev/null; then
    CURRENT_BAR="$(quickshell_read_bar)"
    quickshell_stop
    for _ in {1..30}; do
        pgrep -x quickshell >/dev/null || break
        sleep 0.1
    done
    if pgrep -x quickshell >/dev/null; then
        printf 'Could not stop the running Quickshell instance\n' >&2
        exit 1
    fi
    if [[ "$CURRENT_BAR" != "alt" ]]; then
        quickshell_stop_notification_daemons
        quickshell_start alt || exit 1
        quickshell_write_bar alt
    fi
else
    quickshell_stop_notification_daemons
    quickshell_start alt || exit 1
    quickshell_write_bar alt
fi
