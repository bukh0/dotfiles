#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/quickshell-common.sh"
quickshell_lock
CURRENT_BAR=$(quickshell_read_bar)
case "${1:-}" in
    reload) TARGET_BAR=$CURRENT_BAR;;
    '') if [[ "$CURRENT_BAR" == default ]]; then TARGET_BAR=alt; else TARGET_BAR=default; fi;;
    *) printf 'Usage: %s [reload]\n' "$0" >&2; exit 1;;
esac
quickshell_stop
quickshell_stop_notification_daemons
quickshell_start "$TARGET_BAR"
quickshell_write_bar "$TARGET_BAR"
