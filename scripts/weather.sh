#!/bin/bash

WEATHER=$(curl -sf "https://wttr.in/-25.7479,28.2293?format=%c%t")

if [ -z "$WEATHER" ]; then
  echo "󰼯 N/A"
else
  echo "$WEATHER"
fi
