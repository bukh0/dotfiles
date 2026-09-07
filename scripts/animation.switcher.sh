#!/usr/bin/env bash
ANIM_DIR="$HOME/.config/hypr/animations"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"

CHOICE=$(ls "$ANIM_DIR" | grep "\.lua$" | grep -v "current_animations\|modules\|animations\.lua" | sed 's/\.lua//' | rofi -dmenu -i -p "󰚔 Animations" -config "$ROFI_CONFIG")

[[ -z "$CHOICE" ]] && exit 0

ln -sf "$ANIM_DIR/$CHOICE.lua" "$HOME/.config/hypr/animations.lua"
notify-send -a "System" "Animations set to $CHOICE"
hyprctl reload
