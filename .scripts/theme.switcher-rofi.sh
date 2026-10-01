#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
engine="$SCRIPT_DIR/theme.switcher.sh"
choice=$("$engine" --list-themes | rofi -dmenu -i -p '󰃟 Theme' -config "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi") || exit 0
[[ -n "$choice" ]] || exit 0
case "$choice" in
  Matugen|pywal) exec "$SCRIPT_DIR/wallpick-rofi.sh" --theme "$choice" ;;
  *) exec "$engine" --apply "$choice" ;;
esac
