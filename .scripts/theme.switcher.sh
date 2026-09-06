#!/usr/bin/env bash

# ===================================================================
# 🎨 SELECTION & SETUP
# ===================================================================

# Point this to your centralized themes folder
THEME_DIR="$HOME/.config/hypr/themes"
ROFI_CONF="$HOME/.config/rofi/config.rasi"

# Safely build menu options using 'find' instead of 'ls'
MENU_OPTIONS="Matugen\npywal"
if [[ -d "$THEME_DIR" ]]; then
  # Exclude 'matugen' so it doesn't duplicate in the list
  PRESETS=$(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "matugen" -printf "%f\n" | sort)
  [[ -n "$PRESETS" ]] && MENU_OPTIONS="$MENU_OPTIONS\n$PRESETS"
fi

CHOICE=$(echo -e "$MENU_OPTIONS" | rofi -dmenu -i -p "󰃟 Theme" -config "$ROFI_CONF")
[[ -z "$CHOICE" ]] && exit 0

# ===================================================================
# 🖼️  WALLPAPER HANDLING
# ===================================================================

case "$CHOICE" in
Matugen | pywal)
  WALL_DIR="$HOME/Pictures/Wallpapers"
  cd "$WALL_DIR" || exit 1

  # Safer globbing and sorting for Rofi image menu
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
  # Point static presets to their own wallpaper folders inside THEME_DIR
  WALL_DIR="$THEME_DIR/$CHOICE/wallpapers"
  if [[ -d "$WALL_DIR" ]]; then
    FULL_PATH=$(find "$WALL_DIR" -maxdepth 1 -type f | shuf -n 1)
  else
    FULL_PATH=""
  fi
  ;;
esac

# Apply wallpaper
if [[ -n "$FULL_PATH" && -f "$FULL_PATH" ]]; then
  swww img "$FULL_PATH" --transition-type center --transition-fps 60
fi

# ===================================================================
# 🚀 COLOR GENERATION & SYMLINKING
# ===================================================================

# Helper function to keep Spotify logic clean
update_spotify() {
  local scheme=$1
  if pgrep -x "spotify" >/dev/null; then
    local spicetify_bin
    spicetify_bin=$(command -v spicetify || echo "$HOME/.spicetify/spicetify")

    if [[ -x "$spicetify_bin" ]]; then
      "$spicetify_bin" config current_theme Sleek color_scheme "$scheme"
      "$spicetify_bin" apply -q
    fi
  fi
}

case "$CHOICE" in
Matugen)
  # Tell Matugen exactly where its new config file is
  matugen image "$FULL_PATH" -c "$THEME_DIR/matugen/config.toml" --prefer=saturation

  # Symlink all generated files for Matugen
  ln -sf "$THEME_DIR/matugen/generated/rofi.rasi" "$HOME/.config/rofi/colors.rasi"
  ln -sf "$THEME_DIR/matugen/generated/kitty.conf" "$HOME/.config/kitty/theme.conf"
  ln -sf "$THEME_DIR/matugen/generated/quickshell-colors.qml" "$HOME/.config/quickshell/Colors.qml"
  ln -sf "$THEME_DIR/matugen/generated/waybar.css" "$HOME/.config/waybar/theme.css"

  # Optional: If you use a matugen gtk/swaync template, link them here too
  [[ -f "$THEME_DIR/matugen/generated/gtk.css" ]] && ln -sf "$THEME_DIR/matugen/generated/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
  [[ -f "$THEME_DIR/matugen/generated/swaync.css" ]] && ln -sf "$THEME_DIR/matugen/generated/swaync.css" "$HOME/.config/swaync/style.css"

  update_spotify "Matugen"
  ;;

pywal)
  wal -i "$FULL_PATH" -n -q

  # Symlink all Pywal cache outputs
  ln -sf "$HOME/.cache/wal/colors-rofi-dark.rasi" "$HOME/.config/rofi/colors.rasi"
  ln -sf "$HOME/.cache/wal/colors-kitty.conf" "$HOME/.config/kitty/theme.conf"
  ln -sf "$HOME/.cache/wal/colors.css" "$HOME/.config/gtk-3.0/gtk.css"
  ln -sf "$HOME/.cache/wal/colors-waybar.css" "$HOME/.config/waybar/theme.css"
  ln -sf "$HOME/.cache/wal/colors-swaync.css" "$HOME/.config/swaync/style.css"

  # Convert Pywal JSON colors into a valid QuickShell QML singleton safely
  if [[ -f "$HOME/.cache/wal/colors.json" ]]; then
    python3 -c '
import json, os
try:
    with open(os.path.expanduser("~/.cache/wal/colors.json"), "r") as f:
        data = json.load(f)
    colors = data.get("colors", {})
    special = data.get("special", {})
    
    bg = special.get("background", "#1e1e2e")
    fg = special.get("foreground", "#cdd6f4")
    c0 = colors.get("color0", "#181825")
    c4 = colors.get("color4", "#89b4fa")
    c5 = colors.get("color5", "#f5c2e7")
    c6 = colors.get("color6", "#cba6f7")
    c7 = colors.get("color7", "#cdd6f4")

    qml = f"""pragma Singleton
import QtQuick

QtObject {{
    property string primary: "{c4}"
    property string textPrimary: "{bg}"
    property string primaryContainer: "{c6}"
    property string textPrimaryContainer: "{fg}"
    property string secondary: "{c5}"
    property string textSecondary: "{bg}"
    property string background: "{bg}"
    property string textBackground: "{fg}"
    property string surface: "{c0}"
    property string textSurface: "{c7}"
}}
"""
    with open(os.path.expanduser("~/.config/quickshell/Colors.qml"), "w", encoding="utf-8") as f:
        f.write(qml)
except Exception as e:
    print(f"Error generating pywal quickshell colors: {e}")
'
  fi

  update_spotify "ultra-dark"
  ;;

*)
  # Safely symlink static presets for application components if files exist
  [[ -f "$THEME_DIR/$CHOICE/rofi/colors.rasi" ]] && ln -sf "$THEME_DIR/$CHOICE/rofi/colors.rasi" "$HOME/.config/rofi/colors.rasi"
  [[ -f "$THEME_DIR/$CHOICE/kitty/theme.conf" ]] && ln -sf "$THEME_DIR/$CHOICE/kitty/theme.conf" "$HOME/.config/kitty/theme.conf"
  [[ -f "$THEME_DIR/$CHOICE/swaync/style.css" ]] && ln -sf "$THEME_DIR/$CHOICE/swaync/style.css" "$HOME/.config/swaync/style.css"
  [[ -f "$THEME_DIR/$CHOICE/gtk/gtk.css" ]] && ln -sf "$THEME_DIR/$CHOICE/gtk/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
  [[ -f "$THEME_DIR/$CHOICE/waybar/theme.css" ]] && ln -sf "$THEME_DIR/$CHOICE/waybar/theme.css" "$HOME/.config/waybar/theme.css"

  # Copy the static QuickShell Colors file directly to satisfy module lookup context
  if [[ -f "$THEME_DIR/$CHOICE/quickshell/Colors.qml" ]]; then
    cp "$THEME_DIR/$CHOICE/quickshell/Colors.qml" "$HOME/.config/quickshell/Colors.qml"
  fi

  # Map preset choices to Spicetify themes
  case "$CHOICE" in
  gruvbox) update_spotify "gruvbox" ;;
  catppuccin | catppuccin-mocha) update_spotify "mocha" ;;
  everforest) update_spotify "everforest" ;;
  *) update_spotify "ultra-dark" ;;
  esac
  ;;
esac

# ===================================================================
# 🔄 REFRESH INTERFACE
# ===================================================================

# Reload Kitty
if pgrep -x "kitty" >/dev/null; then
  killall -SIGUSR1 kitty
fi

# Reload QuickShell if active
if pgrep -x "quickshell" >/dev/null; then
  quickshell reload &
fi

# Reload Waybar if active
if pgrep -x "waybar" >/dev/null; then
  killall -SIGUSR2 waybar
fi

if [[ -n "$FULL_PATH" && -f "$FULL_PATH" ]]; then
  notify-send -a "Theme Engine" "Theme updated to $CHOICE" -i "$FULL_PATH"
else
  notify-send -a "Theme Engine" "Theme updated to $CHOICE"
fi
