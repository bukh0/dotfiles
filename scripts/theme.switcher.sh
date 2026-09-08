#!/usr/bin/env bash

THEME_DIR="$HOME/.config/hypr/themes"
ROFI_CONF="$HOME/.config/rofi/config.rasi"

MENU_OPTIONS="Matugen\npywal"
if [[ -d "$THEME_DIR" ]]; then
  PRESETS=$(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "matugen" ! -name "pywal" -printf "%f\n" | sort)
  [[ -n "$PRESETS" ]] && MENU_OPTIONS="$MENU_OPTIONS\n$PRESETS"
fi

CHOICE=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "󰃟 Theme" -config "$ROFI_CONF")
[[ -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
Matugen | pywal)
  WALL_DIR="$HOME/Pictures/Wallpapers"
  cd "$WALL_DIR" || exit 1
  shopt -s nullglob nocaseglob
  mapfile -d '' -t wall_files < <(find . -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -printf '%T@ %p\0' | sort -z -rn | cut -z -d' ' -f2-)
  entries=""
  for f in "${wall_files[@]}"; do
    f="${f#./}"
    entries+="$f\0icon\x1f$WALL_DIR/$f\n"
  done
  SELECTED=$(echo -en "$entries" | rofi -dmenu -i -show-icons -theme "$HOME/.config/rofi/wallpaper.rasi" -p " Wallpaper")
  [[ -z "$SELECTED" ]] && exit 0
  FULL_PATH="$WALL_DIR/$SELECTED"
  ;;
*)
  WALL_DIR="$HOME/Pictures/Wallpapers/$CHOICE"
  if [[ -d "$WALL_DIR" ]]; then
    FULL_PATH=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg \) | shuf -n 1)
  else
    FULL_PATH=""
  fi
  ;;
esac

[[ -n "$FULL_PATH" && -f "$FULL_PATH" ]] && swww img "$FULL_PATH" --transition-type center --transition-fps 60

case "$CHOICE" in
Matugen)
  matugen image "$FULL_PATH" -c "$THEME_DIR/matugen/config.toml" --prefer=saturation
  SRC_DIR="$THEME_DIR/matugen/generated"
  ;;
pywal)
  # --- THE FIX ---
  # Added --backend colorthief to bypass the slow ImageMagick extraction
  wal --backend colorthief -i "$FULL_PATH" -n -q
  python3 "$HOME/.scripts/pywal-generate.py"
  SRC_DIR="$THEME_DIR/pywal/generated"
  
  mkdir -p "$SRC_DIR"
  
  ln -sf "$HOME/.cache/wal/colors-rofi-dark.rasi" "$SRC_DIR/rofi.rasi"
  ln -sf "$HOME/.cache/wal/colors-kitty.conf" "$SRC_DIR/kitty.conf"
  ln -sf "$HOME/.cache/wal/gtk.css" "$SRC_DIR/gtk.css"
  ;;
*)
  SRC_DIR="$THEME_DIR/$CHOICE"
  ;;
esac

atomic_copy() {
  local src=$1 dest=$2
  [[ -f "$src" ]] || return 1
  cp "$src" "${dest}.tmp" && mv "${dest}.tmp" "$dest"
}

declare -A ROUTES=(
  [rofi.rasi]="$HOME/.config/rofi/colors.rasi"
  [kitty.conf]="$HOME/.config/kitty/theme.conf"
  [waybar.css]="$HOME/.config/waybar/theme.css"
  [gtk.css]="$HOME/.config/gtk-3.0/gtk.css"
  [swaync.css]="$HOME/.config/swaync/colors.css"
  [hyprlock.conf]="$HOME/.config/hypr/hyprlock-colors.conf"
  [wlogout.css]="$HOME/.config/wlogout/colors.css"
  [midnight-discord.css]="$HOME/.config/vesktop/themes/midnight-discord.css"
)

mkdir -p "$HOME/.config/vesktop/themes"

for name in "${!ROUTES[@]}"; do
  atomic_copy "$SRC_DIR/$name" "${ROUTES[$name]}"
done

atomic_copy "$SRC_DIR/quickshell-colors.qml" "$HOME/.config/quickshell/Colors.qml"

sleep 0.1

pgrep -x "kitty" >/dev/null && killall -SIGUSR1 kitty
pgrep -x "quickshell" >/dev/null && quickshell reload &
pgrep -x "waybar" >/dev/null && killall -SIGUSR2 waybar
command -v swaync-client >/dev/null && pgrep -x "swaync" >/dev/null && swaync-client -rs >/dev/null 2>&1 &

if [[ -n "$FULL_PATH" && -f "$FULL_PATH" ]]; then
  notify-send -a "Theme Engine" "Theme updated to $CHOICE" -i "$FULL_PATH"
else
  notify-send -a "Theme Engine" "Theme updated to $CHOICE"
fi
