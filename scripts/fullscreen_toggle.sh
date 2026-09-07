#!/bin/bash
FLAG="/tmp/waybar_hidden"

hyprctl dispatch fullscreen 0
sleep 0.05

FS=$(hyprctl activewindow -j | jq '.fullscreen')

if [ "$FS" = "1" ] && [ ! -f "$FLAG" ]; then
    pkill -SIGUSR1 waybar
    touch "$FLAG"
elif [ "$FS" = "0" ] && [ -f "$FLAG" ]; then
    pkill -SIGUSR1 waybar
    rm "$FLAG"
fi
