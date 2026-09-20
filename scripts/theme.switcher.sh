#!/usr/bin/env bash

THEME_DIR="$HOME/.config/hypr/themes"
ROFI_CONF="$HOME/.config/rofi/config.rasi"
WALL_ROOT="$HOME/Pictures/Wallpapers"
THUMB_DIR="$HOME/.cache/wall-thumbs"

mkdir -p "$THUMB_DIR" "$HOME/.config/vesktop/themes"

# ---------- thumbnail cache (pure bash except the magick call) ----------
# REPLY = cache path for $1's thumbnail. The source path is encoded into the
# name so same-named files in different folders can't collide. ('%' is avoided
# on purpose: ImageMagick treats it specially in output filenames.)
thumb_file() { REPLY="$THUMB_DIR/${1//\//+}.jpg"; }

# Build the thumbnail if missing or older than its source. Written to a
# .part file first so an interrupted run never leaves a corrupt thumbnail.
make_thumb() {
  thumb_file "$1"
  [[ $REPLY -nt $1 ]] && return 0
  magick -limit thread 1 -define jpeg:size=1280x720 "$1[0]" \
    -thumbnail 640x -strip -quality 85 "jpg:$REPLY.part" 2>/dev/null &&
    mv -f "$REPLY.part" "$REPLY"
}

# REPLY = thumbnail if it exists, otherwise the original file.
thumb_or_src() {
  thumb_file "$1"
  [[ -f $REPLY ]] || REPLY=$1
}

export THUMB_DIR
export -f thumb_file make_thumb

# ---------- theme menu ----------
MENU=$'Matugen\npywal'
PRESETS=$(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d ! -name matugen ! -name pywal -printf '%f\n' 2>/dev/null | sort)
[[ -n $PRESETS ]] && MENU+=$'\n'"$PRESETS"

CHOICE=$(rofi -dmenu -i -p "󰃟 Theme" -config "$ROFI_CONF" <<<"$MENU")
[[ -z $CHOICE ]] && exit 0

# ---------- wallpaper selection ----------
FULL_PATH=""
case "$CHOICE" in
Matugen | pywal)
  files=() missing=() rows=()

  # one find, newest first; the mtime prefix is stripped with parameter expansion
  while IFS= read -r -d '' rec; do
    f=${rec#* }
    files+=("$f")
    thumb_file "$f"
    [[ $REPLY -nt $f ]] || missing+=("$f")
  done < <(find "$WALL_ROOT" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -printf '%T@ %p\0' | sort -z -rn)

  if ((${#files[@]} == 0)); then
    notify-send -a "Theme Engine" "No wallpapers in $WALL_ROOT"
    exit 1
  fi

  # only spawn workers for thumbnails that are actually missing
  ((${#missing[@]})) &&
    printf '%s\0' "${missing[@]}" | xargs -0 -n1 -P"$(nproc)" bash -c 'make_thumb "$1"' _

  for f in "${files[@]}"; do
    thumb_or_src "$f"
    rows+=("${f##*/}" "$REPLY")
  done

  SELECTED=$(printf '%s\0icon\x1f%s\n' "${rows[@]}" |
    rofi -dmenu -i -show-icons -theme "$HOME/.config/rofi/wallpaper.rasi" -p " Wallpaper")
  [[ -z $SELECTED ]] && exit 0
  FULL_PATH="$WALL_ROOT/$SELECTED"
  ;;
*)
  # random preset wallpaper without find/shuf
  shopt -s nullglob nocaseglob
  imgs=("$WALL_ROOT/$CHOICE"/*.{jpg,png,jpeg})
  ((${#imgs[@]})) && FULL_PATH=${imgs[RANDOM % ${#imgs[@]}]}
  ;;
esac

# swww blocks until its transition ends, so it runs detached and is never waited on
[[ -f $FULL_PATH ]] &&
  swww img "$FULL_PATH" --transition-type center --transition-fps 60 --transition-duration 0.8 &>/dev/null &

# ---------- generate colours ----------
case "$CHOICE" in
Matugen)
  SRC_DIR="$THEME_DIR/matugen/generated"
  matugen image "$FULL_PATH" -c "$THEME_DIR/matugen/config.toml" --prefer=saturation
  ;;
pywal)
  SRC_DIR="$HOME/.cache/wal" # wal renders ~/.config/wal/templates/* here, named like the ROUTES keys
  thumb_or_src "$FULL_PATH"  # 640px thumbnail: colorthief is slow on full-res images
  wal --backend colorthief -i "$REPLY" -n -e -s -t -q
  ;;
*)
  SRC_DIR="$THEME_DIR/$CHOICE"
  ;;
esac

# ---------- install outputs ----------
atomic_copy() {
  [[ -f $1 ]] || return 1
  cp "$1" "$2.tmp" && mv -f "$2.tmp" "$2"
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
  [quickshell-colors.qml]="$HOME/.config/quickshell/Colors.qml" # quickshell live-reloads on change
)

for name in "${!ROUTES[@]}"; do
  atomic_copy "$SRC_DIR/$name" "${ROUTES[$name]}"
done

# ---------- reload ----------
pkill -USR1 -x kitty
pkill -USR2 -x waybar
pgrep -x swaync >/dev/null && swaync-client -rs &>/dev/null &

# ---------- notify (no wait) ----------
notify_args=(-a "Theme Engine")
if [[ -f $FULL_PATH ]]; then
  thumb_or_src "$FULL_PATH"
  notify_args+=(-i "$REPLY")
fi
notify-send "${notify_args[@]}" "Theme updated to $CHOICE"
