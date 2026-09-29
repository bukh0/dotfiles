#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/quickshell-common.sh"
quickshell_lock
CURRENT_BAR=$(quickshell_read_bar)
quickshell_stop
quickshell_stop_notification_daemons
quickshell_start "$CURRENT_BAR"
quickshell_write_bar "$CURRENT_BAR"
