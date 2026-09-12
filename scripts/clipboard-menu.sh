#!/usr/bin/env bash
selected=$(cliphist list | rofi -dmenu -p "clipboard" -no-custom)
[ -z "$selected" ] && exit 0
sleep 0.1
echo "$selected" | cliphist decode | wtype -
