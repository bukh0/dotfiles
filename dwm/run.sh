#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
make

: "${DISPLAY:=:0}"
export DISPLAY
unset WAYLAND_DISPLAY

cleanup() {
    [[ -n "${DWM_PID:-}" ]] && kill "$DWM_PID" 2>/dev/null || true
    kill "${SLSTATUS_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [[ -x "$HOME/.fehbg" ]]; then
    "$HOME/.fehbg" &
fi

if pgrep -x slstatus >/dev/null 2>&1; then
    pkill -x slstatus
    for _ in {1..20}; do
        pgrep -x slstatus >/dev/null 2>&1 || break
        sleep 0.05
    done
fi

./dwm &
DWM_PID=$!

slstatus &
SLSTATUS_PID=$!

wait "$DWM_PID"
