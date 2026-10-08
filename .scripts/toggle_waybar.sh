#!/usr/bin/env bash
set -euo pipefail
source "$HOME/.scripts/quickshell-common.sh"
profile=$(quickshell_read_bar)
qs_dir=$(quickshell_bar_dir "$profile")
if quickshell ipc -p "$qs_dir" call bar available >/dev/null 2>&1; then
    exec quickshell ipc -p "$qs_dir" call bar toggle
fi
if pgrep -u "$UID" -x waybar >/dev/null; then
    pkill -u "$UID" -x waybar
else
    waybar &
fi
