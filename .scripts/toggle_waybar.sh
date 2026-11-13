#!/usr/bin/env bash
set -euo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-toggle-${UID}.lock"
flock -x 9
if pgrep -u "$UID" -x waybar >/dev/null; then
    pkill -u "$UID" -x waybar || [[ $? == 1 ]]
else
    log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
    mkdir -p "$log_dir"
    command -v waybar >/dev/null || { echo "waybar is not installed" >&2; exit 1; }
    nohup waybar >"$log_dir/waybar.log" 2>&1 </dev/null 9>&- &
fi
