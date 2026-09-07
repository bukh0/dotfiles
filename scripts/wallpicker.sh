#!/usr/bin/env bash

ACTIVE_THEME=$(ls -l ~/.config/rofi/colors.rasi | awk -F'/' '{print $(NF-2)}')
WALLPAPER_DIR="$HOME/.themes/wallpapers/$ACTIVE_THEME"

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send -a "System" "No specific wallpapers found for $ACTIVE_THEME"
    exit 1
fi

IMAGE_LIST=""
for img in $(ls "$WALLPAPER_DIR" | grep -E ".jpg$|.jpeg$|.png$|.webp$"); do
    IMAGE_LIST+="$img\0icon\x1f$WALLPAPER_DIR/$img\n"
done

CHOICE=$(echo -e "$IMAGE_LIST" | rofi -dmenu -i -p "󰸉 $ACTIVE_THEME" -config "$HOME/.config/rofi/wallpaper.rasi"  "\n")

[[ -z "$CHOICE" ]] && exit 0

swww img "$WALLPAPER_DIR/$CHOICE" --transition-type grow --transition-pos center
notify-send -a "System" "Wallpaper updated to $CHOICE"
