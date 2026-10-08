#!/usr/bin/env bash
set -euo pipefail

command -v hyprctl >/dev/null
command -v notify-send >/dev/null
command -v jq >/dev/null

STATUS=$(hyprctl getoption decoration:blur:enabled -j | jq -r '
    if (.bool | type) == "boolean" then .bool
    elif (.int | type) == "number" then .int != 0
    else error("Missing blur enabled value") end')
if [ "$STATUS" = "true" ]; then
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } } })'
    notify-send "Hyprland" "Blur Disabled" -i dialog-information -t 1000
else
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } } })'
    notify-send "Hyprland" "Blur Enabled" -i dialog-information -t 1000
fi
