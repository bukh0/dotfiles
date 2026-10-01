#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if (( $# == 0 )); then exec "$SCRIPT_DIR/picker-menu.sh"; fi
(
    flock -x 8
    make -C "$SCRIPT_DIR" --silent theme.switcher
) 8>"${XDG_RUNTIME_DIR:-/tmp}/theme-build-${UID}.lock"
exec "$SCRIPT_DIR/theme.switcher" "$@"
