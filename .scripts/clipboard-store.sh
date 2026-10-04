#!/usr/bin/env bash
# Invoked by wl-paste --watch, with clipboard bytes arriving on stdin.
set -euo pipefail
# wl-paste 2.3 marks x-kde-passwordManagerHint offers as sensitive using the
# same offer as stdin. A separate MIME query can see a newer clipboard entry.
# Store only an explicitly ordinary offer; skip unknown/missing states too.
case "${CLIPBOARD_STATE:-}" in data) ;; *) exit 0 ;; esac
exec cliphist store
