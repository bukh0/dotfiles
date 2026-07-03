#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"

cd "$WALLPAPER_DIR" || exit 1

IFS=$'\n'

SELECTED=$(for f in $(ls -t *.jpg *.png *.gif *.jpeg *.webp 2>/dev/null); do
    echo -en "$f\0icon\x1f$WALLPAPER_DIR/$f\n"
done | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p " Wallpaper")

[[ -z "$SELECTED" ]] && exit 0

FULL_PATH="$WALLPAPER_DIR/$SELECTED"

awww img "$FULL_PATH" \
    --transition-type grow \
    --transition-duration 2 \
    --transition-fps 60 &

matugen image "$FULL_PATH" --source-color-index 0 -q

notify-send -a "Wallpaper" "$(basename "$FULL_PATH")" "Theme updated" -u low -t 2000
