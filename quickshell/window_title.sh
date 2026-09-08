#!/usr/bin/env bash

# 1. Instantly fetch the current window title on startup
hyprctl activewindow -j | grep '"title":' | head -n 1 | cut -d '"' -f 4

# 2. Listen to Hyprland's socket for real-time focus changes
socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | stdbuf -o0 grep '^activewindow>>' | while read -r line; do
    # The socket outputs data in this format: activewindow>>Window_Class,Window_Title
    # We cut out everything after the first comma to isolate the title
    title=$(echo "$line" | cut -d',' -f2-)
    echo "$title"
done
