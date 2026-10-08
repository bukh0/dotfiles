#!/usr/bin/env bash
set -euo pipefail
dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/picker"
[[ -f "$dir/shell.qml" ]] || { printf 'Picker configuration missing: %s\n' "$dir" >&2; exit 1; }
command -v quickshell >/dev/null || { printf 'quickshell is not installed\n' >&2; exit 1; }

# A second keypress dismisses the open picker; closing exits its process.
umask 077
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-picker-${UID}.lock"
flock -x 9
if quickshell ipc -p "$dir" call picker dismiss >/dev/null 2>&1; then exit 0; fi

# Skip make and its build lock when the installed engine is already current.
build_dir="$HOME/.scripts"
engine="$build_dir/theme.switcher"
if [[ ! -x "$engine" || "$build_dir/theme.switcher.cpp" -nt "$engine" || "$build_dir/makefile" -nt "$engine" ]]; then
    (
        flock -x 8
        make -C "$build_dir" --silent theme.switcher
    ) 8>"${XDG_RUNTIME_DIR:-/tmp}/theme-build-${UID}.lock"
fi
log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
mkdir -p "$log_dir"
quickshell -d -n -p "$dir" >"$log_dir/picker.log" 2>&1 9>&-
