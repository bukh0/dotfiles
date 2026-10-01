#!/usr/bin/env bash
# Invoked by wl-paste --watch, with clipboard bytes arriving on stdin.
set -euo pipefail
case "${CLIPBOARD_STATE:-data}" in sensitive|clear|nil) exit 0 ;; esac
types=$(wl-paste --list-types 2>/dev/null) || exit 0
if [[ $'\n'"$types"$'\n' == *$'\nx-kde-passwordManagerHint\n'* ]]; then exit 0; fi
exec cliphist store
