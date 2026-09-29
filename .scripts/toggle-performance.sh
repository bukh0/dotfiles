#!/bin/bash
set -euo pipefail
GPU_PERF=/sys/class/drm/renderD128/device/power_dpm_force_performance_level
GPU_PROFILE=/sys/class/drm/renderD128/device/pp_power_profile_mode
PERF_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/perf-mode"
STATE_LOCK="${XDG_RUNTIME_DIR:-/tmp}/performance-profile-${UID}.lock"

mkdir -p "${XDG_RUNTIME_DIR:-/tmp}" "${PERF_STATE%/*}"
umask 077
exec 9>"$STATE_LOCK"
umask 022
flock -x 9

set_gpu_value() {
    local path="$1"
    local value="$2"
    [[ -e "$path" ]] || return 0
    printf '%s\n' "$value" | sudo tee "$path" >/dev/null
}

mode="auto"
if [[ -r "$PERF_STATE" ]]; then IFS= read -r mode < "$PERF_STATE" || true; fi
[[ -n "$mode" ]] || mode=auto
case "$mode" in
    powersave)
        next="auto"
        label="Balanced (Auto)"
        sudo auto-cpufreq --force=reset
        set_gpu_value "$GPU_PERF" auto
        set_gpu_value "$GPU_PROFILE" 0
        ;;
    auto)
        next="performance"
        label="Performance"
        sudo auto-cpufreq --force=performance
        set_gpu_value "$GPU_PERF" high
        set_gpu_value "$GPU_PROFILE" 1
        ;;
    performance)
        next="powersave"
        label="Power Saver"
        sudo auto-cpufreq --force=powersave
        set_gpu_value "$GPU_PERF" low
        set_gpu_value "$GPU_PROFILE" 0
        ;;
    *)
        next="auto"
        label="Balanced (Auto)"
        sudo auto-cpufreq --force=reset
        set_gpu_value "$GPU_PERF" auto
        set_gpu_value "$GPU_PROFILE" 0
        ;;
esac
state_tmp=$(mktemp "${PERF_STATE}.XXXXXX")
printf '%s\n' "$next" > "$state_tmp"
mv -f -- "$state_tmp" "$PERF_STATE"
notify-send -a "System" "Power Profile" "Switched to $label" -t 2000
