#!/usr/bin/env bash

HYPR_DIR="$HOME/.config/hypr"
ANIM_DIR="$HOME/.config/hypr/animations"
WAYBAR_DIR="$HOME/.config/waybar"
ROFI_CONF="$HOME/.config/rofi/config.rasi"
NVIM_DIR="$HOME/.config/nvim/lua"

MAIN_OPTIONS="1. Hyprland\n2. Waybar\n3. Animations\n4. NvChad"

CHOICE=$(echo -e "$MAIN_OPTIONS" | rofi -dmenu -i -p "󱊟 " -config "$ROFI_CONF")

case "$CHOICE" in
    *Hyprland)
        FILE=$(ls "$HYPR_DIR" | grep ".lua" | rofi -dmenu -i -p "󰧨 Hyprland Configs" -config "$ROFI_CONF")
        [[ -n "$FILE" ]] && kitty -e nvim "$HYPR_DIR/$FILE"
        ;;

    *Waybar)
        PRESET=$(ls -d "$WAYBAR_DIR"/*/ | xargs -n1 basename | rofi -dmenu -i -p "󱗼 Select Waybar Layout" -config "$ROFI_CONF")
        
        if [[ -n "$PRESET" ]]; then
            ln -sf "$WAYBAR_DIR/$PRESET/config.jsonc" "$WAYBAR_DIR/config.jsonc"
            ln -sf "$WAYBAR_DIR/$PRESET/style.css" "$WAYBAR_DIR/style.css"
            
            killall waybar && waybar &
            notify-send -a "System" "Waybar layout changed to $PRESET"
        fi
        ;;

    *Animations)
        ANIM=$(ls "$ANIM_DIR" | grep ".lua" | grep -v "current" | rofi -dmenu -i -p "󰚔 Select Animation" -config "$ROFI_CONF")
        
        if [[ -n "$ANIM" ]]; then
            ln -sf "$ANIM_DIR/$ANIM" "$ANIM_DIR/current_animations.lua"
            ln -sf "$ANIM_DIR/$ANIM" "$HYPR_DIR/animations.lua"
            
            notify-send -a "System" "Animations updated to $ANIM"
            hyprctl reload
        fi
        ;;

    *NvChad)
        # Finds all .lua files in your nvim directory to easily edit plugins, mappings, or chadrc
        FILE=$(find "$NVIM_DIR" -type f -name "*.lua" | sed "s|$NVIM_DIR/||" | rofi -dmenu -i -p " NvChad Configs" -config "$ROFI_CONF")
        [[ -n "$FILE" ]] && kitty -e nvim "$NVIM_DIR/$FILE"
        ;;
esac
