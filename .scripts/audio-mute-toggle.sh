#!/usr/bin/env bash
set -euo pipefail

command -v swayosd-client >/dev/null && command -v wpctl >/dev/null
swayosd-client --output-volume mute-toggle
volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
if [[ "$volume" == *MUTED* ]]; then muted=1; else muted=0; fi

# A hardware LED is optional; do not break software mute when absent.
led=/sys/class/leds/platform::mute/brightness
if [[ -e "$led" ]]; then printf '%s\n' "$muted" | sudo tee "$led" >/dev/null; fi
