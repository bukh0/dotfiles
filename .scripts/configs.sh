#!/usr/bin/env bash

HYPR_DIR="$HOME/.config/hypr"
ANIM_DIR="$HOME/.config/hypr/animations"
WAYBAR_DIR="$HOME/.config/waybar"
ROFI_CONF="$HOME/.config/rofi/config.rasi"
NVIM_DIR="$HOME/.config/nvim"
NOTES_DIR="$HOME/notes"

MAIN_OPTIONS="1. Hyprland\n2. Notes\n3. Nvim\n4. Waybar\n5. Animations"

CHOICE=$(echo -e "$MAIN_OPTIONS" | rofi -dmenu -i -no-custom -p "󱊟 " -config "$ROFI_CONF")

case "$CHOICE" in
  *Hyprland)
    FILE=$(find "$HYPR_DIR" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' | sort | rofi -dmenu -i -no-custom -p "󰧨 Hyprland Configs" -config "$ROFI_CONF")
    [[ -n "$FILE" && "$FILE" != */* && -f "$HYPR_DIR/$FILE" ]] && kitty -e nvim "$HYPR_DIR/$FILE"
    ;;

  *Waybar)
    PRESET=$(find -H "$WAYBAR_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | rofi -dmenu -i -no-custom -p "󱗼 Select Waybar Layout" -config "$ROFI_CONF")

    if [[ -n "$PRESET" ]]; then
      if [[ "$PRESET" == */* || "$PRESET" == . || "$PRESET" == .. ||
        ! -f "$WAYBAR_DIR/$PRESET/config.jsonc" || ! -f "$WAYBAR_DIR/$PRESET/style.css" ]]; then
        notify-send -a "System" "Invalid Waybar layout" "$PRESET"
        exit 1
      fi
      ln -sfnT "$WAYBAR_DIR/$PRESET/config.jsonc" "$WAYBAR_DIR/config.jsonc" || exit 1
      ln -sfnT "$WAYBAR_DIR/$PRESET/style.css" "$WAYBAR_DIR/style.css" || exit 1

      pkill -x waybar 2>/dev/null || true
      waybar &
      notify-send -a "System" "Waybar layout changed to $PRESET"
    fi
    ;;

  *Animations)
    bash "$HOME/.scripts/animation.switcher.sh"
    ;;

  *Nvim)
    FILE=$(find -H "$NVIM_DIR" -type f -name "*.lua" -printf '%P\n' | rofi -dmenu -i -no-custom -p " Nvim Configs" -config "$ROFI_CONF")
    [[ -n "$FILE" && "$FILE" != /* && "/$FILE/" != */../* && -f "$NVIM_DIR/$FILE" ]] && kitty -e nvim "$NVIM_DIR/$FILE"
    ;;

  *Notes)
    VAULT="$NOTES_DIR/uni"
    ACTION=$(printf '%s\n' "Open note" "New note" "Daily note" "Search notes" \
      | rofi -dmenu -i -no-custom -p "󰎞 Notes" -config "$ROFI_CONF")

    case "$ACTION" in
      "Open note")
        mapfile -t FILES < <(find "$NOTES_DIR" -type f -name '*.md' -not -path '*/.git/*' -printf '%T@ %p\n' \
        | sort -rn | cut -d' ' -f2-)
        IDX=$(for f in "${FILES[@]}"; do basename "$f" .md; done \
          | rofi -dmenu -i -no-custom -format i -p "󰎞 Open note" -config "$ROFI_CONF")
        [[ -n "$IDX" ]] && kitty -d "$VAULT" -e nvim "${FILES[$IDX]}"
        ;;
      "New note")
        TITLE=$(rofi -dmenu -p "󰎞 Note title" -config "$ROFI_CONF" < /dev/null | tr -d '"|\\')
        [[ -n "$TITLE" ]] && kitty -d "$VAULT" -e nvim -c "Obsidian new $TITLE"
        ;;
      "Daily note")
        kitty -d "$VAULT" -e nvim -c "Obsidian today"
        ;;
      "Search notes")
        kitty -d "$VAULT" -e nvim -c "Obsidian search"
        ;;
    esac
    ;;
esac
