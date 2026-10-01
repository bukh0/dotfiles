#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
engine="$SCRIPT_DIR/theme.switcher.sh"
theme=
if [[ ${1:-} == --theme ]]; then
  [[ $# == 2 ]] || exit 2
  theme=$2
  [[ $theme == Matugen || $theme == pywal ]] || exit 2
elif [[ $# != 0 ]]; then
  exit 2
fi
walls=$("$engine" --list-walls)
[[ -n "$walls" ]] || { notify-send -a Wallpaper 'No wallpapers found'; exit 0; }
choice_file=
menu=$(mktemp)
trap 'rm -f -- "$menu" "$choice_file"' EXIT
choice_file=$(mktemp)
while IFS=$'\t' read -r path thumb; do
  [[ -n $path ]] || continue
  [[ -s $thumb ]] || thumb=$path
  printf '%s\0icon\x1f%s\n' "$path" "$thumb" >> "$menu"
done <<< "$walls"
rofi -dmenu -i -show-icons -theme "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpaper.rasi" -p ' Wallpaper' < "$menu" > "$choice_file" || exit 0
selected=$(<"$choice_file")
[[ -n $selected ]] || exit 0
if [[ -n $theme ]]; then
  rm -f -- "$menu" "$choice_file"
  trap - EXIT
  exec "$engine" --apply "$theme" "$selected"
fi
swww img "$selected" --transition-type grow --transition-duration 2 --transition-fps 60
notify-send -a Wallpaper -i "$selected" 'Wallpaper changed' "${selected##*/}" -u low -t 2500
