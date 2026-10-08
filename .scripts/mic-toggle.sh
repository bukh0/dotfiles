#!/usr/bin/env bash
set -euo pipefail

for c in wpctl swayosd-client; do command -v "$c" >/dev/null || exit 1; done
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
volume=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
if [[ "$volume" == *MUTED* ]]; then
    muted=1
    label=("Mic Muted" "microphone-sensitivity-muted")
else
    muted=0
    label=("Mic Active" "microphone-sensitivity-high")
fi
brightnessctl --device=platform::micmute set "$muted" >/dev/null 2>&1 || true
swayosd-client --custom-message "${label[0]}" --custom-icon "${label[1]}"
