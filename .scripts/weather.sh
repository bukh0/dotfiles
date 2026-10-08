#!/bin/bash

LOC=${WEATHER_LOCATION:-}
if [[ -z "$LOC" ]]; then
    IFS= read -r LOC < "${XDG_CONFIG_HOME:-$HOME/.config}/weather-location" 2>/dev/null || true
fi
if [[ -z "$LOC" ]]; then printf '󰼯 N/A\n'; exit 0; fi

WEATHER=$(curl --fail --silent --show-error --max-time 8 \
  "https://wttr.in/${LOC}?format=%c%t" 2>/dev/null || true)

if [ -z "$WEATHER" ]; then
  echo "󰼯 N/A"
else
  echo "$WEATHER"
fi
