#!/usr/bin/env bash
mode=auto
IFS= read -r mode < "${XDG_CACHE_HOME:-$HOME/.cache}/perf-mode" 2>/dev/null || mode=auto
case "$mode" in
    performance) echo "󰓅" ;;
    auto)        echo "󰾅" ;;
    powersave)   echo "󰌪" ;;
    *)           echo "󰾅" ;;
esac
