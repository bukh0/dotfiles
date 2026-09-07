#!/bin/bash
STATUS=$(hyprctl getoption decoration:blur:enabled | head -1 | awk '{print $2}')
if [ "$STATUS" = "true" ]; then
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } } })'
    notify-send "Hyprland" "Blur Disabled" -i dialog-information -t 1000
else
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } } })'
    notify-send "Hyprland" "Blur Enabled" -i dialog-information -t 1000
fi
