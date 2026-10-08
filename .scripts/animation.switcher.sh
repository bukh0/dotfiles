#!/usr/bin/env bash
set -euo pipefail
ANIM_DIR="$HOME/.config/hypr/animations"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"
CHOICE=$(find "$ANIM_DIR" -maxdepth 1 -type f -name '*.lua' \
    ! -name 'current_animations.lua' ! -name 'animations.lua' \
    -printf '%f\n' | sed 's/\.lua$//' | sort | \
    rofi -dmenu -i -no-custom -p "󰚔 Animations" -config "$ROFI_CONFIG") || exit 0
[[ -n "$CHOICE" ]] || exit 0
[[ "$CHOICE" != */* && -f "$ANIM_DIR/$CHOICE.lua" ]] || { printf 'Invalid animation selection\n' >&2; exit 1; }
ln -sfn -- "$ANIM_DIR/$CHOICE.lua" "$ANIM_DIR/current_animations.lua"
ln -sfn -- "$ANIM_DIR/$CHOICE.lua" "$HOME/.config/hypr/animations.lua"
hyprctl reload
notify-send -a "System" "Animations set to $CHOICE"
