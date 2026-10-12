#!/usr/bin/env bash
set -euo pipefail

command -v hyprctl >/dev/null
exec hyprctl dispatch 'hl.dsp.window.fullscreen({ action = "toggle" })'
