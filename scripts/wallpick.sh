#!/usr/bin/env bash

# ===================================================================
# ⚙️ CONFIGURATION
# ===================================================================
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"

# Ensure dependencies are installed before running
for cmd in rofi swww matugen notify-send; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# ===================================================================
# 🖼️ FETCH & FORMAT MENU
# ===================================================================
cd "$WALLPAPER_DIR" || exit 1
shopt -s nullglob nocaseglob

# NUL-safe file list sorted by modification time (newest first)
mapfile -d '' -t files < <(find . -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -printf '%T@ %p\0' | sort -z -rn | cut -z -d' ' -f2-)

# Exit cleanly if no wallpapers are found
[[ ${#files[@]} -eq 0 ]] && {
  notify-send "Wallpaper" "No images found in $WALLPAPER_DIR"
  exit 0
}

# Build the Rofi dmenu string with icon references
entries=""
for f in "${files[@]}"; do
  f="${f#./}"
  entries+="$f\0icon\x1f$WALLPAPER_DIR/$f\n"
done

# ===================================================================
# 🚀 EXECUTION
# ===================================================================
# Launch Rofi
SELECTED=$(echo -en "$entries" | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p "  Wallpaper")
[[ -z "$SELECTED" ]] && exit 0

FULL_PATH="$WALLPAPER_DIR/$SELECTED"

# Apply wallpaper asynchronously so the script doesn't hang
swww img "$FULL_PATH" \
  --transition-type grow \
  --transition-duration 2 \
  --transition-fps 60 &

# Generate colors silently
matugen image "$FULL_PATH" --source-color-index 0 -q

# Send notification using the selected wallpaper as the thumbnail
notify-send -a "Wallpaper" "Theme Updated" "$(basename "$FULL_PATH")" \
  -i "$FULL_PATH" -u low -t 2500
