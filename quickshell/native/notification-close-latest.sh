#!/usr/bin/env bash
set -euo pipefail

source "$HOME/.scripts/quickshell-common.sh"
profile=$(quickshell_read_bar)
exec qs ipc -p "$(quickshell_bar_dir "$profile")" call notifications closeLatest
