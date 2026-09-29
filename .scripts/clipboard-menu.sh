#!/usr/bin/env bash
# A separate Quickshell popup; the bar and its launcher are not involved.
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/clipboard"
for dependency in quickshell python3 cliphist wl-copy flock; do
    if ! command -v "$dependency" >/dev/null; then
        printf 'Clipboard: required command is missing: %s\n' "$dependency" >&2
        exit 1
    fi
done
if [[ ! -f "$config/shell.qml" ]]; then
    printf 'Clipboard config not found: %s\n' "$config/shell.qml" >&2
    exit 1
fi

# Serialize key repeats and concurrent invocations; release before launching.
umask 077
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-clipboard-${UID}.lock"
flock -x 9
if quickshell ipc -p "$config" call clipboard toggle >/dev/null 2>&1; then
    exit 0
fi
QS_CLIPBOARD_CONTEXT=$(python3 "$config/backend.py" context) \
    quickshell -p "$config" --no-duplicate --daemonize 9>&-
