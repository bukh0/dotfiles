#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/quickshell-common.sh"
quickshell_lock
CURRENT_BAR=$(quickshell_read_bar)
if quickshell_running; then
    quickshell_stop
    [[ "$CURRENT_BAR" != alt ]] || exit 0
fi
quickshell_stop_notification_daemons
quickshell_start alt
quickshell_write_bar alt
