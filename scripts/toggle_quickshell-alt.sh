#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/quickshell_current_bar"

if pgrep -x "quickshell" > /dev/null; then
    killall quickshell 2>/dev/null
else
    # Prevent notification daemon conflicts before claiming the bus
    killall swaync dunst mako notification-daemon 2>/dev/null
    printf "%s\n" "quickshell-alt" > "$STATE_FILE"
    quickshell -p "$HOME/.config/quickshell-alt" > "$HOME/.cache/quickshell-alt.log" 2>&1 &
fi
