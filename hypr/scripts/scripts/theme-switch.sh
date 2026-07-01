#!/usr/bin/env bash
# ~/.config/hypr/scripts/theme-switch.sh

THEME_STATE="$HOME/.config/hypr/.current-theme"

# If an image path is passed, use Matugen
if [ -f "$1" ]; then
    echo "matugen" > "$THEME_STATE"
    matugen image "$1"
    
    # Reload Hyprland to apply the new colors to borders
    hyprctl reload
    
    # Reload waybar/swaync if you have matugen templates for them too
    # pkill -SIGUSR2 waybar
    # swaync-client -rs
    
    exit 0
fi

# If a preset name is passed (like 'catppuccin' or 'gruvbox')
if [ -n "$1" ]; then
    echo "$1" > "$THEME_STATE"
    hyprctl reload
    exit 0
fi

# If no arguments, default to matugen
echo "matugen" > "$THEME_STATE"
hyprctl reload
