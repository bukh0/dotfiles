#!/usr/bin/env bash

HYPR_DIR="$HOME/.config/hypr"
ANIM_DIR="$HOME/.config/hypr/animations"
WAYBAR_DIR="$HOME/.config/waybar"
ROFI_CONF="$HOME/.config/rofi/config.rasi"
NVIM_DIR="$HOME/.config/nvim"

MAIN_OPTIONS="1. Hyprland\n2. Waybar\n3. Animations\n4. Nvim"

CHOICE=$(echo -e "$MAIN_OPTIONS" | rofi -dmenu -i -p "󱊟 " -config "$ROFI_CONF")

case "$CHOICE" in
    *Hyprland)
        FILE=$(find "$HYPR_DIR" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' | sort | rofi -dmenu -i -p "󰧨 Hyprland Configs" -config "$ROFI_CONF")
        [[ -n "$FILE" ]] && kitty -e nvim "$HYPR_DIR/$FILE"
        ;;

    *Waybar)
        PRESET=$(find "$WAYBAR_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | rofi -dmenu -i -p "󱗼 Select Waybar Layout" -config "$ROFI_CONF")
        
        if [[ -n "$PRESET" ]]; then
            ln -sf "$WAYBAR_DIR/$PRESET/config.jsonc" "$WAYBAR_DIR/config.jsonc"
            ln -sf "$WAYBAR_DIR/$PRESET/style.css" "$WAYBAR_DIR/style.css"
            
            pkill -x waybar 2>/dev/null || true
            waybar &
            notify-send -a "System" "Waybar layout changed to $PRESET"
        fi
        ;;

    *Animations)
        bash "$HOME/.scripts/animation.switcher.sh"
        ;;

    *Nvim)
        # Finds all .lua files in your nvim directory to easily edit plugins, mappings, or chadrc
        FILE=$(find "$NVIM_DIR" -type f -name "*.lua" | sed "s|$NVIM_DIR/||" | rofi -dmenu -i -p " Nvim Configs" -config "$ROFI_CONF")
        [[ -n "$FILE" ]] && kitty -e nvim "$NVIM_DIR/$FILE"
        ;;
esac
