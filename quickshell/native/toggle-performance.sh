#!/bin/bash
set -euo pipefail

export SUDO_ASKPASS="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/performance-askpass.sh"

# Preserve the user's script and its unprivileged cache/notification writes.
# Only its existing sudo calls use graphical authentication.
sudo() { command sudo --askpass "$@"; }
export -f sudo
exec bash "$HOME/.scripts/toggle-performance.sh"
