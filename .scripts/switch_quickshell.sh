#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/quickshell_current_bar"

# Read state instantly without spawning 'cat'
if [[ -f "$STATE_FILE" ]]; then
    read -r CURRENT_BAR < "$STATE_FILE"
else
    CURRENT_BAR="quickshell"
fi

if [[ "$1" == "reload" ]]; then
    TARGET_BAR="$CURRENT_BAR"
else
    # Swap layout
    [[ "$CURRENT_BAR" == "quickshell" ]] && TARGET_BAR="quickshell-alt" || TARGET_BAR="quickshell"
    # Write instantly without spawning 'echo'
    printf "%s\n" "$TARGET_BAR" > "$STATE_FILE"
fi

# pkill -0 is the fastest process check (sends signal 0, exits 0 if process exists)
if pkill -0 -x "quickshell" 2>/dev/null; then
    killall quickshell 2>/dev/null
    sleep 0.2
    killall swaync dunst mako notification-daemon 2>/dev/null
    
    # Use native reload scripts which you already have
    bash "$HOME/.config/$TARGET_BAR/reload.sh" &
fi
