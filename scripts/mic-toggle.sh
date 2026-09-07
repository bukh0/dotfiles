#!/bin/bash

# 1. Toggle the default microphone (survives reboots)
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

# 2. Check the true mute state
MUTE=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -c MUTED)

# 3. Sync the ThinkPad hardware LED (no sudo required)
brightnessctl --device='platform::micmute' set $MUTE > /dev/null

# 4. Trigger the custom SwayOSD notification
if [ "$MUTE" -eq 1 ]; then
    swayosd-client --custom-message "Mic Muted" --custom-icon "microphone-sensitivity-muted"
else
    swayosd-client --custom-message "Mic Active" --custom-icon "microphone-sensitivity-high"
fi
