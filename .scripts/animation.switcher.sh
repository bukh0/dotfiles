#!/usr/bin/env bash
ANIM_DIR="$HOME/.config/hypr/animations"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"

CHOICE=$(find "$ANIM_DIR" -maxdepth 1 -type f -name '*.lua' \
  ! -name 'current_animations.lua' ! -name 'animations.lua' \
  -printf '%f\n' | sed 's/\.lua$//' | sort |
  rofi -dmenu -i -p "󰚔 Animations" -config "$ROFI_CONFIG")

[[ -z "$CHOICE" ]] && exit 0

ln -sf "$ANIM_DIR/$CHOICE.lua" "$HOME/.config/hypr/animations.lua"
notify-send -a "System" "Animations set to $CHOICE"
hyprctl reload
