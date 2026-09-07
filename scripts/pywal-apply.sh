#!/bin/bash

# ── Pick wallpaper via rofi file browser ──────────────────────────────────────
WALLPAPER=$(find ~/Pictures -type f \( -iname "*.jpg" -o -iname "*.jpeg" \
    -o -iname "*.png" -o -iname "*.webp" \) | sort \
    | rofi -dmenu -i -p "  Wallpaper")

[[ -z "$WALLPAPER" ]] && exit 0

# ── Set wallpaper ─────────────────────────────────────────────────────────────
swww img "$WALLPAPER" --transition-type wipe --transition-duration 1

# ── Generate palette ──────────────────────────────────────────────────────────
wal -i "$WALLPAPER" -n -q   # -n = no X11, -q = quiet

# ── Deploy templates to config locations ──────────────────────────────────────
cp ~/.cache/wal/waybar-theme.css   ~/.config/waybar/theme.css
cp ~/.cache/wal/rofi-colors.rasi   ~/.config/rofi/colors.rasi
cp ~/.cache/wal/kitty-theme.conf   ~/.config/kitty/theme.conf

# ── Reload apps ───────────────────────────────────────────────────────────────
pkill -SIGUSR2 waybar            # reload waybar CSS
swaync-client --reload-css       # swaync imports waybar theme.css
kill -SIGUSR1 $(pgrep kitty) 2>/dev/null   # live-reload kitty colors

notify-send "pywal" "Theme applied from $(basename "$WALLPAPER")" --icon=preferences-desktop-wallpaper
