#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
make

SLSTATUS_BIN=slstatus
if [[ -f "$HOME/slstatus/Makefile" ]]; then
    make -C "$HOME/slstatus"
    SLSTATUS_BIN="$HOME/slstatus/slstatus"
fi

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

"$SLSTATUS_BIN" &
SLSTATUS_PID=$!

wait "$DWM_PID"
