#!/bin/bash
set -o pipefail

# Default bar count - adjusted for a middle-bar "pill"
bars=12 
vert=0
clean=1 # Default to clean (hides when silent)

usage() {
    local fd=1
    (( ${1:-0} )) && fd=2
    printf 'Usage: %s [--vert] [--clean] [--bars N | --N]\n' "${0##*/}" >&$fd
    exit "${1:-0}"
}

validate_bars() {
    [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 )) || {
        printf 'Invalid bar count: %s\n' "$1" >&2
        exit 1
    }
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --vert)    vert=1 ;;
        --clean)   clean=1 ;;
        --bars)
            [[ -n ${2+x} ]] || { printf 'Missing value for --bars\n' >&2; exit 1; }
            bars="$2"; shift
            validate_bars "$bars"
            ;;
        --bars=*)
            bars="${1#--bars=}"
            validate_bars "$bars"
            ;;
        --[0-9]*)
            bars="${1#--}"
            validate_bars "$bars"
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage 1
            ;;
    esac
    shift
done

command -v cava >/dev/null 2>&1 || {
    printf 'cava: command not found\n' >&2
    exit 1
}

trap 'kill 0 2>/dev/null' EXIT

# We set the background to 'none' in cava config to prevent clashing with your pills
cava -p <(printf '%s\n' \
    '[general]' \
    "bars = $bars" \
    'framerate = 60' \
    '' \
    '[output]' \
    'method = raw' \
    'raw_target = /dev/stdout' \
    'data_format = ascii' \
    'ascii_max_range = 7'
) | awk -v vert="$vert" -v clean="$clean" '
BEGIN {
    # Unicode bars
    c[0] = " "; c[1] = "▂"; c[2] = "▃"; c[3] = "▄"
    c[4] = "▅"; c[5] = "▆"; c[6] = "▇"; c[7] = "█"
    idle     = 0
    blanked  = 0
    threshold = 60
}
{
    n       = split($0, raw, ";")
    nbars   = 0
    all_zero = 1

    for (i = 1; i <= n; i++) {
        if (raw[i] == "") continue
        nbars++
        actual = raw[i] + 0
        if (actual < 0) actual = 0
        if (actual > 7) actual = 7

        # Smooth decay logic
        decayed   = prev[nbars] - 1
        displayed = (actual > decayed) ? actual : decayed
        if (displayed < 0) displayed = 0

        prev[nbars] = displayed
        if (displayed > 0) all_zero = 0
    }

    if (clean && all_zero) idle++
    else                   idle = 0

    if (clean && idle > threshold) {
        if (!blanked) {
            printf "{\"text\":\"\", \"class\":\"silent\"}\n"
            fflush()
            blanked = 1
        }
        next
    }
    blanked = 0

    # Build Output String
    out = ""
    for (i = 1; i <= nbars; i++) {
        if (vert && i > 1) out = out "\\n"
        out = out c[prev[i]]
    }

    # Output as JSON for Waybar styling
    printf "{\"text\":\"%s\", \"class\":\"active\"}\n", out
    fflush()
}'
