#!/usr/bin/env bash
killall quickshell 2>/dev/null
# Give the old instance a moment to release its socket before the new one binds.
sleep 0.3
quickshell -p ~/.config/quickshell-alt > ~/.cache/quickshell-alt.log 2>&1 &
