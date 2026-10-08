#!/usr/bin/env bash
set -euo pipefail

for c in wpctl swayosd-client; do command -v "$c" >/dev/null || exit 1; done
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
if [[ "$volume" == *MUTED* ]]; then
    muted=1; icon=audio-volume-muted; msg="Muted"
else
    muted=0; icon=audio-volume-high; msg="Unmuted"
fi
swayosd-client --custom-message "$msg" --custom-icon "$icon"

# A hardware LED is optional; do not break software mute when absent.
led=/sys/class/leds/platform::mute/brightness
if [[ -e "$led" ]]; then printf '%s\n' "$muted" | sudo tee "$led" >/dev/null; fi
