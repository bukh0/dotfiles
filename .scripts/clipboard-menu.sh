#!/usr/bin/env bash
set -o pipefail
selected=$(cliphist list | rofi -dmenu -p "clipboard" -no-custom)
[ -z "$selected" ] && exit 0
sleep 0.1
printf '%s\n' "$selected" | cliphist decode | wtype -
