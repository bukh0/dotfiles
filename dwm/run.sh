#!/usr/bin/env bash

# 1. Compile C binary
make || exit 1

# 2. Kill ghost instances
pkill -x dwm 2>/dev/null
pkill -x slstatus 2>/dev/null

sleep 0.1

# 3. Paint canvas
if [ -f ~/.fehbg ]; then
    DISPLAY=:2 ~/.fehbg &
fi

# 4. Launch Window Manager in the background, grab its exact PID
env -u WAYLAND_DISPLAY DISPLAY=:2 ./dwm &
DWM_PID=$!

# 5. THE BRIDGE: Give dwm 200ms to open the root window property
sleep 0.2

# 6. Mount the status bar daemon
DISPLAY=:2 slstatus &

# 7. Anchor this script to dwm's PID so the sub-shells stay alive
wait $DWM_PID
