#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/quickshell_current_bar"

# Default to the standard bar if no state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo "quickshell" > "$STATE_FILE"
fi

CURRENT_BAR=$(cat "$STATE_FILE")

if pgrep -x "quickshell" > /dev/null; then
    killall quickshell 2>/dev/null
else
    # Prevent notification daemon conflicts before claiming the bus
    killall swaync dunst mako notification-daemon 2>/dev/null
    quickshell -p "$HOME/.config/$CURRENT_BAR" > "$HOME/.cache/${CURRENT_BAR}.log" 2>&1 &
fi
