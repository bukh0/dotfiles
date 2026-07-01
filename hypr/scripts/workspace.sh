#!/bin/bash
echo "$1" >> /tmp/waybar-workspace.log
hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $1 }))"
