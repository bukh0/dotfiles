#!/bin/bash
if systemctl --user is-active gamemoded.service &>/dev/null; then
    systemctl --user stop gamemoded.service
    notify-send -a "System" "Game Mode" "Disabled" -t 2000
else
    systemctl --user start gamemoded.service
    notify-send -a "System" "Game Mode" "Enabled 󰊴" -t 2000
fi
