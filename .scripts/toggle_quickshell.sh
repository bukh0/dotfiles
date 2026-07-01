#!/usr/bin/env bash
if pgrep -x "quickshell" > /dev/null; then
    pkill -x quickshell
else
    quickshell &
fi
