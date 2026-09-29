#!/usr/bin/env bash

QS_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
QS_STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell_current_bar"
QS_DEFAULT_BAR=default
QS_BARS=(default alt)

quickshell_lock() {
    mkdir -p "${XDG_RUNTIME_DIR:-/tmp}"
    umask 077
    exec 8>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-controls-${UID}.lock"
    umask 022
    flock -x 8
}

quickshell_bar_dir() {
    case "$1" in default|alt) printf '%s/profiles/%s\n' "$QS_ROOT" "$1";; *) return 1;; esac
}

quickshell_read_bar() {
    local bar=""
    if [[ -r "$QS_STATE_FILE" ]]; then IFS= read -r bar < "$QS_STATE_FILE" || true; fi
    case "$bar" in default|alt) printf '%s\n' "$bar";; *) printf '%s\n' "$QS_DEFAULT_BAR";; esac
}

quickshell_write_bar() {
    local bar="$1" tmp
    [[ "$bar" == default || "$bar" == alt ]] || return 1
    mkdir -p "${QS_STATE_FILE%/*}" || return 1
    tmp=$(mktemp "${QS_STATE_FILE}.XXXXXX") || return 1
    if printf '%s\n' "$bar" > "$tmp" && mv -f -- "$tmp" "$QS_STATE_FILE"; then return 0; fi
    rm -f -- "$tmp"
    return 1
}

# Match these two configurations only; other Quickshell applications may run.
quickshell_pids() {
    local pid i candidate
    local -a args
    while IFS= read -r pid; do
        [[ -r /proc/$pid/cmdline ]] || continue
        args=()
        mapfile -d '' -t args < "/proc/$pid/cmdline" || continue
        for ((i=1; i<${#args[@]}-1; i++)); do
            case "${args[i]}" in
                -p|--path)
                    candidate=$(realpath -m -- "${args[i+1]}")
                    case "$candidate" in
                        "$(realpath -m "$QS_ROOT/profiles/default")"|"$(realpath -m "$QS_ROOT/profiles/default/shell.qml")"|"$(realpath -m "$QS_ROOT/profiles/alt")"|"$(realpath -m "$QS_ROOT/profiles/alt/shell.qml")") printf '%s\n' "$pid"; break;;
                    esac;;
                -c|--config)
                    case "${args[i+1]}" in default|alt) printf '%s\n' "$pid"; break;; esac;;
            esac
        done
    done < <(pgrep -u "$UID" -x quickshell || true)
}

quickshell_running() { [[ -n "$(quickshell_pids)" ]]; }

quickshell_stop() {
    local pid
    local -a pids
    mapfile -t pids < <(quickshell_pids)
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    for _ in {1..30}; do
        quickshell_running || return 0
        sleep 0.1
    done
    printf 'Could not stop the running Quickshell profile\n' >&2
    return 1
}

quickshell_stop_notification_daemons() {
    local name
    for name in swaync dunst mako; do pkill -u "$UID" -x "$name" 2>/dev/null || true; done
    # Linux comm names are limited to 15 bytes.
    pkill -u "$UID" -x notification-da 2>/dev/null || true
}

quickshell_start() {
    local bar="$1" dir
    dir=$(quickshell_bar_dir "$bar") || return 1
    [[ -f "$dir/shell.qml" && -x "$QS_ROOT/run.sh" ]] || return 1
    # Use the shared build, PID tracking, start validation and launcher lock.
    # The detached shell must not inherit this control-script lock.
    "$QS_ROOT/run.sh" "$bar" 8>&-
}
