#!/bin/bash

swayosd-client --output-volume mute-toggle

# Give swayosd a moment to apply
sleep 0.05

MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -c MUTED)
echo "$MUTED" | sudo tee /sys/class/leds/platform::mute/brightness > /dev/null
