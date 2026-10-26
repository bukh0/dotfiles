#!/usr/bin/env bash
mode=auto
state="${XDG_CACHE_HOME:-$HOME/.cache}/perf-mode"
# read returns failure for a valid final line without a newline.
if [[ -r "$state" ]]; then IFS= read -r mode < "$state" || true; fi
case "$mode" in
    performance) echo "󰓅" ;;
    auto)        echo "󰾅" ;;
    powersave)   echo "󰌪" ;;
    *)           echo "󰾅" ;;
esac
