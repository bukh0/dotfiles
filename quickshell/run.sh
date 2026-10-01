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

command -v quickshell >/dev/null || { echo "quickshell is not installed" >&2; exit 1; }
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}" "$(dirname "$PID_FILE")"
# Serialize profile switches so concurrent reloads cannot leave two bars.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-${UID}.lock"
flock -x 9

# Protect the shared binary from concurrent compiler/linker writes too.
make -C "$CONFIG_DIR/native" --silent || echo "sysmon build failed; continuing" >&2

is_profile_process() {
    local pid="$1" expected="$2" i candidate
    local -a args=()
    [[ "$pid" =~ ^[0-9]+$ && -r /proc/$pid/cmdline ]] || return 1
    mapfile -d '' -t args < "/proc/$pid/cmdline" || return 1
    # Also allow an interpreted quickshell wrapper, as used by the tests.
    local program="${args[0]:-}"
    [[ "${program##*/}" == quickshell || "${args[1]:-}" == */quickshell ]] || return 1
    expected=$(realpath -m -- "$expected") || return 1
    for ((i=1; i<${#args[@]}; i++)); do
        case "${args[i]}" in
            -p|--path) candidate="${args[i+1]:-}" ;;
            --path=*) candidate="${args[i]#--path=}" ;;
            *) continue ;;
        esac
        [[ -n "$candidate" ]] || return 1
        # Interpret relative config paths in the process's working directory.
        [[ "$candidate" == /* ]] || candidate="/proc/$pid/cwd/$candidate"
        [[ "${candidate##*/}" != shell.qml ]] || candidate="${candidate%/*}"
        [[ "$(realpath -m -- "$candidate")" == "$expected" ]] && return 0
    done
    return 1
}

stop_existing() {
    shopt -s nullglob
    local pid_files=("${XDG_RUNTIME_DIR:-/tmp}"/quickshell-"${UID}"-*.pid)
    shopt -u nullglob

    local pf
    for pf in "${pid_files[@]}"; do
        [ -r "$pf" ] || continue
        local old_pid profile
        old_pid="$(cat "$pf")"
        profile="${pf##*/}"
        profile="${profile#quickshell-${UID}-}"
        profile="${profile%.pid}"
        case "$profile" in ''|.|..|*[!A-Za-z0-9._-]*) continue ;; esac
        if is_profile_process "$old_pid" "$CONFIG_DIR/profiles/$profile"; then
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

LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/${PROFILE_NAME}.log"
for _ in {1..100}; do
    if ! kill -0 "$QUICKSHELL_PID" 2>/dev/null || grep -q '^State:[[:space:]]*Z' "/proc/$QUICKSHELL_PID/status" 2>/dev/null; then
        break
    fi
    if grep -qF 'Configuration Loaded' "$LOG_FILE"; then exit 0; fi
    sleep 0.1
done
# Only the child launched above is stopped on a startup timeout.
kill "$QUICKSHELL_PID" 2>/dev/null || true
rm -f "$PID_FILE"
printf 'Quickshell did not finish loading; see %s\n' "$LOG_FILE" >&2
exit 1
