#!/bin/bash
GPU_PERF=/sys/class/drm/renderD128/device/power_dpm_force_performance_level
GPU_PROFILE=/sys/class/drm/renderD128/device/pp_power_profile_mode

mode=$(cat ~/.cache/perf-mode 2>/dev/null || echo "auto")
case "$mode" in
    powersave)
        next="auto"
        label="Balanced (Auto)"
        sudo auto-cpufreq --force=reset
        echo auto | sudo tee $GPU_PERF > /dev/null
        echo 0 | sudo tee $GPU_PROFILE > /dev/null
        ;;
    auto)
        next="performance"
        label="Performance"
        sudo auto-cpufreq --force=performance
        echo high | sudo tee $GPU_PERF > /dev/null
        echo 1 | sudo tee $GPU_PROFILE > /dev/null
        ;;
    performance)
        next="powersave"
        label="Power Saver"
        sudo auto-cpufreq --force=powersave
        echo low | sudo tee $GPU_PERF > /dev/null
        echo 0 | sudo tee $GPU_PROFILE > /dev/null
        ;;
    *)
        next="auto"
        label="Balanced (Auto)"
        sudo auto-cpufreq --force=reset
        echo auto | sudo tee $GPU_PERF > /dev/null
        ;;
esac
echo "$next" > ~/.cache/perf-mode
notify-send -a "System" "Power Profile" "Switched to $label" -t 2000
