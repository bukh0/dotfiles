#!/usr/bin/env bash

QS_STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell_current_bar"
QS_DEFAULT_BAR="default"
QS_BARS=(default alt)

quickshell_bar_dir() {
    case "$1" in
        default) printf '%s/.config/quickshell/default\n' "$HOME" ;;
        alt) printf '%s/.config/quickshell/alt\n' "$HOME" ;;
        *) return 1 ;;
    esac
}

quickshell_read_bar() {
    local bar
    if [[ -r "$QS_STATE_FILE" ]]; then
        IFS= read -r bar < "$QS_STATE_FILE" || true
    fi
    case "$bar" in
        default|alt) printf '%s\n' "$bar" ;;
        *) printf '%s\n' "$QS_DEFAULT_BAR" ;;
    esac
}

quickshell_write_bar() {
    local bar="$1"
    local state_dir
    [[ "$bar" == "default" || "$bar" == "alt" ]] || return 1
    state_dir="${QS_STATE_FILE%/*}"
    mkdir -p "$state_dir"
    printf '%s\n' "$bar" > "$QS_STATE_FILE"
}

quickshell_stop() {
    pkill -x quickshell 2>/dev/null || true
}

quickshell_stop_notification_daemons() {
    pkill -x swaync 2>/dev/null || true
    pkill -x dunst 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
    pkill -x notification-daemon 2>/dev/null || true
}

quickshell_start() {
    local bar="$1"
    local dir
    local pid
    dir="$(quickshell_bar_dir "$bar")" || return 1
    [[ -f "$dir/shell.qml" ]] || return 1
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    quickshell -p "$dir" > "${XDG_CACHE_HOME:-$HOME/.cache}/${bar}.log" 2>&1 &
    pid=$!
    sleep 0.2
    if ! kill -0 "$pid" 2>/dev/null; then
        printf 'Quickshell failed to start; see %s.log\n' "${XDG_CACHE_HOME:-$HOME/.cache}/${bar}" >&2
        return 1
    fi
}
