#!/usr/bin/env bash

# ===================================================================
# 🎨 SELECTION & SETUP
# ===================================================================

PRESET_DIR="$HOME/.themes/presets"
ROFI_CONF="$HOME/.config/rofi/config.rasi"

# Removed 'cat' to prevent standard input hanging. Added 2>/dev/null to ls.
CHOICE=$( { echo "Matugen"; echo "pywal"; ls "$PRESET_DIR" 2>/dev/null; } | rofi -dmenu -i -p "󰃟 Theme" -config "$ROFI_CONF")

[[ -z "$CHOICE" ]] && exit 0

# ===================================================================
# 🖼️  WALLPAPER HANDLING
# ===================================================================

if [ "$CHOICE" == "Matugen" ] || [ "$CHOICE" == "pywal" ]; then
    WALL_DIR="$HOME/Pictures/Wallpapers"
else
    WALL_DIR="$HOME/.themes/wallpapers/$CHOICE"
fi

if [ "$CHOICE" == "Matugen" ] || [ "$CHOICE" == "pywal" ]; then
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
else
    # Check if the wallpaper directory exists for the preset to avoid 'ls' errors
    if [ -d "$WALL_DIR" ]; then
        RANDOM_WALL=$(ls "$WALL_DIR" | shuf -n 1)
        FULL_PATH="$WALL_DIR/$RANDOM_WALL"
    else
        FULL_PATH="" 
    fi
fi

# Only apply wallpaper if a valid path was found
if [ -n "$FULL_PATH" ] && [ -f "$FULL_PATH" ]; then
    swww img "$FULL_PATH" --transition-type center --transition-fps 60
fi

# ===================================================================
# 🚀 COLOR GENERATION & SYMLINKING
# ===================================================================

if [ "$CHOICE" == "Matugen" ]; then
    matugen image "$FULL_PATH" --prefer=saturation

    ln -sf "$HOME/.config/matugen/generated/rofi.rasi" "$HOME/.config/rofi/colors.rasi"
    ln -sf "$HOME/.config/matugen/generated/kitty.conf"  "$HOME/.config/kitty/theme.conf"
    
    # TIP: Add any QuickShell specific matugen symlinks here if needed

    if pgrep -x "spotify" > /dev/null; then
        spicetify config current_theme Sleek color_scheme Matugen
        spicetify apply -q
    fi

elif [ "$CHOICE" == "pywal" ]; then
    wal -i "$FULL_PATH" -n -q

    ln -sf "$HOME/.cache/wal/rofi-colors.rasi"  "$HOME/.config/rofi/colors.rasi"
    ln -sf "$HOME/.cache/wal/kitty-theme.conf"   "$HOME/.config/kitty/theme.conf"
    ln -sf "$HOME/.cache/wal/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

    if pgrep -x "spotify" > /dev/null; then
        spicetify config current_theme Sleek color_scheme ultra-dark
        spicetify apply -q
    fi

else
    ln -sf "$PRESET_DIR/$CHOICE/rofi/colors.rasi" "$HOME/.config/rofi/colors.rasi"
    ln -sf "$PRESET_DIR/$CHOICE/kitty/theme.conf"  "$HOME/.config/kitty/theme.conf"
    ln -sf "$PRESET_DIR/$CHOICE/swaync/style.css"  "$HOME/.config/swaync/style.css"
    ln -sf "$PRESET_DIR/$CHOICE/gtk/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
    
    # TIP: Symlink any static QuickShell preset configs here

    if pgrep -x "spotify" > /dev/null; then
        case "$CHOICE" in
            "gruvbox")    spicetify config current_theme Sleek color_scheme gruvbox ;;
            "catppuccin") spicetify config current_theme Sleek color_scheme mocha ;;
            "everforest") spicetify config current_theme Sleek color_scheme everforest ;;
            *)            spicetify config current_theme Sleek color_scheme ultra-dark ;;
        esac
        spicetify apply -q
    fi
fi

# ===================================================================
# 🔄 REFRESH INTERFACE
# ===================================================================

# Add your QuickShell reload command here if it requires one
# e.g., quickshell reload

# Reload Kitty (which will dynamically update Neovim if it uses terminal colors)
if pgrep -x "kitty" > /dev/null; then
    killall -SIGUSR1 kitty
fi

if [ -n "$FULL_PATH" ] && [ -f "$FULL_PATH" ]; then
    notify-send -a "System" "Theme updated to $CHOICE" -i "$FULL_PATH"
else
    notify-send -a "System" "Theme updated to $CHOICE"
fi
