#!/usr/bin/env bash

# ===================================================================
# 🛠️  FUNCTIONS
# ===================================================================

update_vscodium() {
    local theme=$1
    case "$theme" in
        "Matugen")    vsc_theme="Default Dark Modern" ;;
        "pywal")      vsc_theme="Default Dark Modern" ;;
        "gruvbox")    vsc_theme="Gruvbox Dark Soft" ;;
        "catppuccin") vsc_theme="Catppuccin Mocha" ;;
        "everforest") vsc_theme="Everforest Dark Soft" ;;
        *)            vsc_theme="Default Dark Modern" ;;
    esac
    sed -i "s/\"workbench.colorTheme\": \".*\"/\"workbench.colorTheme\": \"$vsc_theme\"/" "$HOME/.config/VSCodium/User/settings.json"
}

# ===================================================================
# 🎨 SELECTION & SETUP
# ===================================================================

PRESET_DIR="$HOME/.themes/presets"
ROFI_CONF="$HOME/.config/rofi/config.rasi"

CHOICE=$( { cat; echo "Matugen"; echo "pywal"; ls "$PRESET_DIR"; } | rofi -dmenu -i -p "󰃟 Theme" -config "$ROFI_CONF")

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
    RANDOM_WALL=$(ls "$WALL_DIR" | shuf -n 1)
    FULL_PATH="$WALL_DIR/$RANDOM_WALL"
fi

swww img "$FULL_PATH" --transition-type center --transition-fps 60

# ===================================================================
# 🚀 COLOR GENERATION & SYMLINKING
# ===================================================================

if [ "$CHOICE" == "Matugen" ]; then
    matugen image "$FULL_PATH" --prefer=saturation

    # FIXED: Now points to rofi.rasi instead of colors.rasi
    ln -sf "$HOME/.config/matugen/generated/rofi.rasi" "$HOME/.config/rofi/colors.rasi"
    ln -sf "$HOME/.config/matugen/generated/waybar.css"  "$HOME/.config/waybar/theme.css"
    ln -sf "$HOME/.config/matugen/generated/kitty.conf"  "$HOME/.config/kitty/theme.conf"

    if pgrep -x "spotify" > /dev/null; then
        spicetify config current_theme Sleek color_scheme Matugen
        spicetify apply -q
    fi

elif [ "$CHOICE" == "pywal" ]; then
    wal -i "$FULL_PATH" -n -q

    ln -sf "$HOME/.cache/wal/waybar-theme.css" "$HOME/.config/waybar/theme.css"
    ln -sf "$HOME/.cache/wal/rofi-colors.rasi"  "$HOME/.config/rofi/colors.rasi"
    ln -sf "$HOME/.cache/wal/kitty-theme.conf"   "$HOME/.config/kitty/theme.conf"
    ln -sf "$HOME/.cache/wal/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

    if pgrep -x "spotify" > /dev/null; then
        spicetify config current_theme Sleek color_scheme ultra-dark
        spicetify apply -q
    fi

else
    ln -sf "$PRESET_DIR/$CHOICE/rofi/colors.rasi" "$HOME/.config/rofi/colors.rasi"
    ln -sf "$PRESET_DIR/$CHOICE/waybar/theme.css"  "$HOME/.config/waybar/theme.css"
    ln -sf "$PRESET_DIR/$CHOICE/kitty/theme.conf"  "$HOME/.config/kitty/theme.conf"
    ln -sf "$PRESET_DIR/$CHOICE/swaync/style.css"  "$HOME/.config/swaync/style.css"
    ln -sf "$PRESET_DIR/$CHOICE/gtk/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

    update_vscodium "$CHOICE"

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

killall waybar && waybar &

if pgrep -x "kitty" > /dev/null; then
    kill -SIGUSR1 $(pgrep kitty)
fi

notify-send -a "System" "Theme updated to $CHOICE" -i "$FULL_PATH"
