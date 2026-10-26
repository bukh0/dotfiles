#!/usr/bin/env bash
# stdin and CLIPBOARD_STATE describe the same captured wl-paste offer.
set -euo pipefail
if [[ "${CLIPBOARD_STATE:-}" != data ]]; then
    cat >/dev/null
    exit 0
fi
# Serialize watcher writers. Leave duplicate detection to cliphist; distinct
# text and image representations are not interchangeable clipboard payloads.
umask 077
lock_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"
mkdir -p -- "$lock_dir"
exec 9>"$lock_dir/qs-clip-store.lock"
flock 9
cliphist store
