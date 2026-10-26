#!/usr/bin/env bash
set -euo pipefail

case "${1:-full}" in
    region)
        geometry=$(slurp) || exit 0
        [[ -n "$geometry" ]] || exit 0
        capture_args=(-g "$geometry")
        label="Region captured"
        ;;
    full)
        capture_args=()
        label="Fullscreen captured"
        ;;
    *) printf 'Usage: %s [full|region]\n' "$0" >&2; exit 2 ;;
esac

directory="$HOME/Pictures/Screenshots"
mkdir -p -- "$directory"
# Reserve a unique name even when the shortcut is pressed twice in one second.
file=$(mktemp "$directory/screenshot-$(date +%Y%m%d-%H%M%S)-XXXXXX.png")
trap 'rm -f -- "$file"' EXIT
grim "${capture_args[@]}" "$file"
trap - EXIT
notify-send -a Screenshot -i "$file" -h "string:image-path:$file" "Screenshot Saved" "$label" || true
