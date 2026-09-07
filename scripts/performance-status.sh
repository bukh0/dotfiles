#!/bin/bash
mode=$(cat ~/.cache/perf-mode 2>/dev/null || echo "auto")
case "$mode" in
    performance) echo "󰓅" ;;
    auto)        echo "󰾅" ;;
    powersave)   echo "󰌪" ;;
    *)           echo "󰾅" ;;
esac
