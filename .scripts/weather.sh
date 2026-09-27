#!/bin/bash

WEATHER=$(curl --fail --silent --show-error --max-time 8 \
  "https://wttr.in/-25.7479,28.2293?format=%c%t" 2>/dev/null || true)

if [ -z "$WEATHER" ]; then
  echo "󰼯 N/A"
else
  echo "$WEATHER"
fi
