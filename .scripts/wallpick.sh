#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if (( $# == 0 )); then exec "$SCRIPT_DIR/picker-menu.sh"; fi
exec "$SCRIPT_DIR/theme.switcher.sh" --apply Matugen "$@"
