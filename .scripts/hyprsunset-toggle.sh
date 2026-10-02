#!/usr/bin/env bash
set -euo pipefail

command -v pgrep >/dev/null
command -v pkill >/dev/null
command -v hyprsunset >/dev/null

if pgrep -u "$UID" -x hyprsunset >/dev/null; then
    pkill -u "$UID" -x hyprsunset
else
    hyprsunset -t 4500 &
fi
