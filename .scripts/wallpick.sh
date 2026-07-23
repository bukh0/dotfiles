#!/usr/bin/env bash
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"

shopt -s nullglob nocaseglob
cd "$WALLPAPER_DIR" || exit 1

# NUL-safe, space-safe file list sorted by modification time (newest first).
mapfile -d '' -t files < <(find . -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -printf '%T@ %p\0' | sort -z -rn | cut -z -d' ' -f2-)

entries=""
for f in "${files[@]}"; do
    f="${f#./}"
    entries+="$f\0icon\x1f$WALLPAPER_DIR/$f\n"
done

SELECTED=$(echo -en "$entries" | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p " Wallpaper")
[[ -z "$SELECTED" ]] && exit 0

FULL_PATH="$WALLPAPER_DIR/$SELECTED"

swww img "$FULL_PATH" \
    --transition-type grow \
    --transition-duration 2 \
    --transition-fps 60 &

matugen image "$FULL_PATH" --source-color-index 0 -q
notify-send -a "Wallpaper" "$(basename "$FULL_PATH")" "Theme updated" -u low -t 2000
