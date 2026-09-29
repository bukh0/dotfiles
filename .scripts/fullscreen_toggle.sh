#!/usr/bin/env bash
set -euo pipefail

command -v hyprctl >/dev/null && command -v jq >/dev/null || exit 1
FLAG="${XDG_RUNTIME_DIR:-/tmp}/waybar-hidden-${UID}"
# false is a valid state; jq -e would make set -e abort before restoring Waybar.
fullscreen=$(hyprctl activewindow -j | jq -r '(.fullscreen // 0) != 0')

if [[ "$fullscreen" == true && ! -e "$FLAG" ]]; then
    pkill -u "$UID" -USR1 -x waybar || exit 1
    : > "$FLAG"
elif [[ "$fullscreen" == false && -e "$FLAG" ]]; then
    pkill -u "$UID" -USR1 -x waybar || exit 1
    rm -f -- "$FLAG"
fi
