#!/usr/bin/env bash

# Kill Quickshell
killall quickshell 2>/dev/null

# Give it a moment to release sockets
sleep 0.3

# Annihilate any auto-started notification daemons before claiming the bus
killall swaync dunst mako notification-daemon 2>/dev/null

# Start Quickshell
quickshell -p ~/.config/quickshell > ~/.cache/quickshell.log 2>&1 &
