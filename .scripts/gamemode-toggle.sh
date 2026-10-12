#!/usr/bin/env bash
set -euo pipefail

for cmd in systemctl systemd-run gamemoded notify-send flock; do command -v "$cmd" >/dev/null; done
unit=desktop-gamemode.service
exec 9>"${XDG_RUNTIME_DIR:?}/desktop-gamemode.lock"
flock -n 9 || exit 0

fail() {
    notify-send -a "System" "Game Mode" "$1" -t 3000
    exit 1
}

# Own one request; leave the daemon and requests from running games alone.
if systemctl --user is-active --quiet "$unit"; then
    systemctl --user stop "$unit" || fail "Could not remove manual request"
    notify-send -a "System" "Game Mode" "Manual request disabled" -t 2000
else
    systemd-run --user --quiet --collect --unit="$unit" \
        --property=KillSignal=SIGINT --property=TimeoutStopSec=5s \
        -- "$(command -v gamemoded)" --request || fail "Could not start manual request"
    # A running process is not yet proof that GameMode registered it.
    for ((attempt=0; attempt<30; attempt++)); do
        pid=$(systemctl --user show "$unit" --property=MainPID --value) || pid=
        if [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
            status=$(LC_ALL=C gamemoded --status="$pid" 2>/dev/null) || status=
            if [[ "$status" == *"active and [$pid] registered"* ]]; then
                notify-send -a "System" "Game Mode" "Manual request enabled" -t 2000
                exit 0
            fi
        fi
        systemctl --user is-active --quiet "$unit" || break
        sleep 0.1
    done
    systemctl --user stop "$unit" || true
    fail "GameMode did not register the manual request"
fi
