#!/usr/bin/env bash
# Now identical to run.sh's race-avoidance and logging.
killall quickshell 2>/dev/null
sleep 0.3
quickshell -p ~/.config/quickshell > ~/.cache/quickshell.log 2>&1 &
