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

menu_file=$(mktemp "${TMPDIR:-/tmp}/quickshell-theme-menu.XXXXXX") || exit 1
choice_file=$(mktemp "${TMPDIR:-/tmp}/quickshell-theme-choice.XXXXXX") || {
  rm -f "$menu_file"
  exit 1
}
trap 'rm -f -- "$menu_file" "$choice_file" "${wall_menu_file:-}" "${wall_choice_file:-}"' EXIT
printf '%s\n' "$MENU" > "$menu_file"
rofi -dmenu -i -p "󰃟 Theme" -config "$ROFI_CONF" < "$menu_file" > "$choice_file"
CHOICE=$(<"$choice_file")
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

  wall_menu_file=$(mktemp "${TMPDIR:-/tmp}/quickshell-wall-menu.XXXXXX") || exit 1
  wall_choice_file=$(mktemp "${TMPDIR:-/tmp}/quickshell-wall-choice.XXXXXX") || exit 1
  printf '%s\0icon\x1f%s\n' "${rows[@]}" > "$wall_menu_file"
  rofi -dmenu -i -show-icons -theme "$HOME/.config/rofi/wallpaper.rasi" \
    -p " Wallpaper" < "$wall_menu_file" > "$wall_choice_file"
  SELECTED=$(<"$wall_choice_file")
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
  matugen image "$FULL_PATH" -c "$THEME_DIR/matugen/config.toml" --prefer=saturation ||
    { notify-send -a "Theme Engine" "Theme generation failed"; exit 1; }
  ;;
pywal)
  SRC_DIR="$HOME/.cache/wal" # wal renders ~/.config/wal/templates/* here, named like the ROUTES keys
  thumb_or_src "$FULL_PATH"  # 640px thumbnail: colorthief is slow on full-res images
  wal --backend colorthief -i "$REPLY" -n -e -s -t -q ||
    { notify-send -a "Theme Engine" "Theme generation failed"; exit 1; }
  ;;
*)
  SRC_DIR="$THEME_DIR/$CHOICE"
  ;;
esac

[[ -n $SRC_DIR ]] || {
  notify-send -a "Theme Engine" "No theme output was generated"
  exit 1
}

# ---------- install outputs ----------
atomic_copy() {
  [[ -f $1 ]] || return 1
  local tmp
  tmp=$(mktemp "${2}.tmp.XXXXXX") || return 1
  if cp "$1" "$tmp"; then
    if mv -f "$tmp" "$2"; then
      return 0
    fi
    rm -f "$tmp"
    return 1
  else
    rm -f "$tmp"
    return 1
  fi
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
  [quickshell-colors.qml]="$HOME/.config/quickshell/shared/Colors.qml" # both profiles link to the shared module
)

source_name() {
  local name="$1"
  if [[ $CHOICE == Matugen && $name == gtk.css ]]; then
    printf '%s\n' gtk-3.css
  else
    printf '%s\n' "$name"
  fi
}

backup_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-theme-backup.XXXXXX") || exit 1
declare -A BACKUPS=()
declare -A HAD_DEST=()
declare -A TOUCHED=()
cleanup_theme_transaction() {
  rm -rf -- "$backup_dir" "${menu_file:-}" "${choice_file:-}" \
    "${wall_menu_file:-}" "${wall_choice_file:-}"
}
rollback_theme_transaction() {
  local name destination backup
  for name in "${!ROUTES[@]}"; do
    [[ ${TOUCHED[$name]:-0} == 1 ]] || continue
    destination="${ROUTES[$name]}"
    backup="${BACKUPS[$name]:-}"
    if [[ -n $backup && -f $backup ]]; then
      cp -f "$backup" "$destination"
    elif [[ ${HAD_DEST[$name]:-0} == 0 ]]; then
      rm -f -- "$destination"
    fi
  done
}
trap 'cleanup_theme_transaction' EXIT

for name in "${!ROUTES[@]}"; do
  source="$SRC_DIR/$(source_name "$name")"
  if [[ $CHOICE == pywal && $name == midnight-discord.css && ! -f $source ]]; then
    continue
  fi
  if [[ ! -f $source ]]; then
    notify-send -a "Theme Engine" "Missing theme output: $(basename "$source")"
    exit 1
  fi
done

for name in "${!ROUTES[@]}"; do
  destination="${ROUTES[$name]}"
  source="$SRC_DIR/$(source_name "$name")"
  if [[ $CHOICE == pywal && $name == midnight-discord.css && ! -f $source ]]; then
    continue
  fi
  mkdir -p "$(dirname "$destination")"
  if [[ -f $destination ]]; then
    backup="$backup_dir/$name"
    if ! cp -f "$destination" "$backup"; then
      rollback_theme_transaction
      notify-send -a "Theme Engine" "Failed to back up $name"
      exit 1
    fi
    BACKUPS[$name]="$backup"
    HAD_DEST[$name]=1
  else
    HAD_DEST[$name]=0
  fi
  TOUCHED[$name]=1
  if ! mkdir -p "$(dirname "$destination")"; then
    rollback_theme_transaction
    notify-send -a "Theme Engine" "Failed to prepare destination for $name"
    exit 1
  fi
  if ! atomic_copy "$SRC_DIR/$(source_name "$name")" "$destination"; then
    rollback_theme_transaction
    notify-send -a "Theme Engine" "Failed to install $name"
    exit 1
  fi
done

# ---------- reload ----------
pkill -USR1 -x kitty
pkill -USR2 -x waybar
pgrep -x swaync >/dev/null && swaync-client -rs &>/dev/null &
if pgrep -x quickshell >/dev/null; then
  if ! "$HOME/.scripts/switch_quickshell.sh" reload; then
    notify-send -a "Theme Engine" "Theme colors installed, but Quickshell reload failed"
    exit 1
  fi
fi

# ---------- notify (no wait) ----------
notify_args=(-a "Theme Engine")
if [[ -f $FULL_PATH ]]; then
  thumb_or_src "$FULL_PATH"
  notify_args+=(-i "$REPLY")
fi
notify-send "${notify_args[@]}" "Theme updated to $CHOICE"
