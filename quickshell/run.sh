#!/usr/bin/env bash
CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$CONFIG_DIR/default"
PROFILE_NAME="default"

pkill -x quickshell 2>/dev/null || true
for _ in {1..30}; do
    pgrep -x quickshell >/dev/null || break
    sleep 0.1
done
if pgrep -x quickshell >/dev/null; then
    printf 'Could not stop the existing Quickshell instance\n' >&2
    exit 1
fi
pkill -x swaync 2>/dev/null || true
pkill -x dunst 2>/dev/null || true
pkill -x mako 2>/dev/null || true
pkill -x notification-daemon 2>/dev/null || true
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
quickshell -p "$SCRIPT_DIR" > "${XDG_CACHE_HOME:-$HOME/.cache}/${PROFILE_NAME}.log" 2>&1 &
pid=$!
sleep 0.2
if ! kill -0 "$pid" 2>/dev/null; then
    printf 'Quickshell failed to start; see %s.log\n' "${XDG_CACHE_HOME:-$HOME/.cache}/${PROFILE_NAME}" >&2
    exit 1
fi
