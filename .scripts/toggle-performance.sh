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
mode=auto
if [[ -r "$PERF_STATE" ]]; then IFS= read -r mode < "$PERF_STATE" || true; fi
[[ -n "$mode" ]] || mode=auto
case "$mode" in
    powersave) next=auto; cpu=reset; gpu=auto; profile=0; label="Balanced (Auto)" ;;
    performance) next=powersave; cpu=powersave; gpu=low; profile=0; label="Power Saver" ;;
    auto) next=performance; cpu=performance; gpu=high; profile=1; label="Performance" ;;
    *) mode=auto; next=auto; cpu=reset; gpu=auto; profile=0; label="Balanced (Auto)" ;;
esac
state_tmp=$(mktemp "${PERF_STATE}.XXXXXX")
trap 'rm -f -- "$state_tmp"' EXIT
printf '%s\n' "$next" > "$state_tmp"
sudo auto-cpufreq --force="$cpu"
# Commit the CPU state before GPU writes; failure there cannot leave the UI
# advertising the previous CPU mode. Roll CPU back if committing itself fails.
if ! mv -f -- "$state_tmp" "$PERF_STATE"; then
    old_cpu=$mode; [[ "$old_cpu" != auto ]] || old_cpu=reset
    sudo auto-cpufreq --force="$old_cpu" || printf 'CPU rollback failed; profile state may be stale\n' >&2
    exit 1
fi
set_gpu_value() {
    local path="$1" value="$2"
    [[ -e "$path" ]] || return 0
    printf '%s\n' "$value" | sudo tee "$path" >/dev/null
}
if ! set_gpu_value "$GPU_PERF" "$gpu" || ! set_gpu_value "$GPU_PROFILE" "$profile"; then
    printf 'CPU profile applied; GPU profile update failed\n' >&2
    notify-send -a System "Power Profile" "CPU switched to $label; GPU settings could not be updated."
    exit 1
fi
notify-send -a System "Power Profile" "Switched to $label" -t 2000
