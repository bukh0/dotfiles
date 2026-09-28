#!/usr/bin/env bash
set -euo pipefail
CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="${1:-default}"

case "$PROFILE_NAME" in
    ''|.|..|*[!A-Za-z0-9._-]*)
        printf 'Invalid profile name: %s\n' "$PROFILE_NAME" >&2
        exit 1
        ;;
esac

SCRIPT_DIR="$CONFIG_DIR/profiles/$PROFILE_NAME"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell-${UID}-${PROFILE_NAME}.pid"

if [ ! -f "$SCRIPT_DIR/shell.qml" ] || [ ! -f "$SCRIPT_DIR/Theme.qml" ]; then
    printf 'No such profile: %s (expected %s)\n' "$PROFILE_NAME" "$SCRIPT_DIR" >&2
    exit 1
fi

make -C "$CONFIG_DIR/native" --silent || echo "sysmon build failed; continuing" >&2

command -v quickshell >/dev/null || { echo "quickshell is not installed" >&2; exit 1; }
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}" "$(dirname "$PID_FILE")"
# Serialize profile switches so concurrent reloads cannot leave two bars.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-${UID}.lock"
flock -x 9

stop_existing() {
    shopt -s nullglob
    local pid_files=("${XDG_RUNTIME_DIR:-/tmp}"/quickshell-"${UID}"-*.pid)
    shopt -u nullglob

    local pf
    for pf in "${pid_files[@]}"; do
        [ -r "$pf" ] || continue
        local old_pid
        old_pid="$(cat "$pf")"
        if [[ "$old_pid" =~ ^[0-9]+$ ]] &&
           [ -r "/proc/$old_pid/cmdline" ] &&
           tr '\0' ' ' < "/proc/$old_pid/cmdline" | grep -qE '(^|/)quickshell([[:space:]]|$)'; then
            kill "$old_pid" 2>/dev/null || true
            for _ in {1..30}; do
                kill -0 "$old_pid" 2>/dev/null || break
                grep -q '^State:[[:space:]]*Z' "/proc/$old_pid/status" 2>/dev/null && break
                sleep 0.1
            done
            if kill -0 "$old_pid" 2>/dev/null &&
               ! grep -q '^State:[[:space:]]*Z' "/proc/$old_pid/status" 2>/dev/null; then
                printf 'Could not stop the existing Quickshell instance (pid %s)\n' "$old_pid" >&2
                exit 1
            fi
        fi
        rm -f "$pf"
    done
}

stop_existing

setsid quickshell -p "$SCRIPT_DIR" > "${XDG_CACHE_HOME:-$HOME/.cache}/${PROFILE_NAME}.log" 2>&1 9>&- &
QUICKSHELL_PID=$!
printf '%s\n' "$QUICKSHELL_PID" > "$PID_FILE"

sleep 0.5

if ! kill -0 "$QUICKSHELL_PID" 2>/dev/null || grep -q '^State:[[:space:]]*Z' "/proc/$QUICKSHELL_PID/status" 2>/dev/null; then
    rm -f "$PID_FILE"
    printf 'Quickshell failed to start; see %s.log\n' "${XDG_CACHE_HOME:-$HOME/.cache}/${PROFILE_NAME}" >&2
    exit 1
fi
