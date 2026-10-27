#!/bin/bash
set -euo pipefail

export SUDO_ASKPASS="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/performance-askpass.sh"

# Preserve the user's script and its unprivileged cache/notification writes.
# Only its existing sudo calls use graphical authentication.
sudo() {
    rm -f -- "$QS_PERFORMANCE_CANCEL_FILE" || return $?
    if command sudo --askpass "$@"; then
        : > "$QS_PERFORMANCE_APPLIED_FILE"
    else
        return $?
    fi
}
export -f sudo
# Keep cancellation metadata private and scoped to this invocation.
state_dir=$(mktemp -d "${TMPDIR:-/tmp}/qs-performance.XXXXXXXX")
trap 'rm -rf -- "$state_dir"' EXIT
export QS_PERFORMANCE_CANCEL_FILE="$state_dir/cancelled"
export QS_PERFORMANCE_APPLIED_FILE="$state_dir/applied"
if bash "${QS_PERFORMANCE_SCRIPT:-$HOME/.scripts/toggle-performance.sh}"; then
    exit 0
else
    status=$?
    # A later cancellation may leave an already-applied CPU/GPU change;
    # retain the failure report in that case.
    if [[ -e "$QS_PERFORMANCE_CANCEL_FILE" && ! -e "$QS_PERFORMANCE_APPLIED_FILE" ]]; then exit 130; fi
    exit "$status"
fi
