#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/quickshell_current_bar"

if [[ -f "$STATE_FILE" ]]; then
    read -r CURRENT_BAR < "$STATE_FILE"
else
    CURRENT_BAR="quickshell"
    printf "%s\n" "$CURRENT_BAR" > "$STATE_FILE"
fi

killall swaync dunst mako notification-daemon 2>/dev/null
quickshell -p "$HOME/.config/$CURRENT_BAR" > "$HOME/.cache/${CURRENT_BAR}.log" 2>&1 &
