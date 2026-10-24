#!/bin/bash
# sudo normalizes askpass failures to exit 1; carry cancellation separately.
if zenity --password --title="Power Profile" --text="${1:-Authentication is required to change the power profile.}"; then
    exit 0
else
    status=$?
    if [[ $status == 1 && -n ${QS_PERFORMANCE_CANCEL_FILE:-} ]]; then
        : > "$QS_PERFORMANCE_CANCEL_FILE"
    fi
    exit "$status"
fi
