#!/usr/bin/env bash
set -euo pipefail
dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/picker"
[[ -f "$dir/shell.qml" ]] || { printf 'Picker configuration missing: %s\n' "$dir" >&2; exit 1; }
command -v quickshell >/dev/null || { printf 'quickshell is not installed\n' >&2; exit 1; }

# Build on demand after a fresh checkout; keep simultaneous linkers serialized.
build_dir="$HOME/.scripts"
(
    flock -x 8
    make -C "$build_dir" --silent theme.switcher
) 8>"${XDG_RUNTIME_DIR:-/tmp}/theme-build-${UID}.lock"

# Serialize rapid key presses; the detached picker must not inherit the lock.
umask 077
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-picker-${UID}.lock"
flock -x 9
# The UI ignores dismissal while applying, so a second key press cannot
# interrupt theme generation or leave partially installed theme files.
if quickshell ipc -p "$dir" call picker dismiss >/dev/null 2>&1; then exit 0; fi
# Support toggling an older picker that does not yet have the IPC handler.
if quickshell kill -p "$dir" >/dev/null 2>&1; then exit 0; fi
log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
mkdir -p "$log_dir"
quickshell -d -n -p "$dir" >"$log_dir/picker.log" 2>&1 9>&-
