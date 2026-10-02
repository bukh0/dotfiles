#!/usr/bin/env bash
set -euo pipefail

command -v systemctl >/dev/null
command -v notify-send >/dev/null

if systemctl --user is-active gamemoded.service &>/dev/null; then
    systemctl --user stop gamemoded.service || exit 1
    notify-send -a "System" "Game Mode" "Disabled" -t 2000
else
    systemctl --user start gamemoded.service || exit 1
    notify-send -a "System" "Game Mode" "Enabled 󰊴" -t 2000
fi
