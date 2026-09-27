#!/bin/bash
set -euo pipefail
GPU_PERF=/sys/class/drm/renderD128/device/power_dpm_force_performance_level
GPU_PROFILE=/sys/class/drm/renderD128/device/pp_power_profile_mode
PERF_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/perf-mode"

set_gpu_value() {
    local path="$1"
    local value="$2"
    [[ -e "$path" ]] || return 0
    printf '%s\n' "$value" | sudo tee "$path" >/dev/null
}

mode="auto"
[[ -r "$PERF_STATE" ]] && IFS= read -r mode < "$PERF_STATE"
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
        ;;
esac
mkdir -p "${PERF_STATE%/*}"
printf '%s\n' "$next" > "$PERF_STATE"
notify-send -a "System" "Power Profile" "Switched to $label" -t 2000
