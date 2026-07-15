#!/bin/bash

# Get the current global layout
CURRENT_LAYOUT=$(hyprctl getoption general:layout -j | jq -r '.str')

# Determine the next layout and its specific border color
if [ "$CURRENT_LAYOUT" = "dwindle" ]; then
    NEW_LAYOUT="master"
    BORDER_COLOR="rgb(30beee) rgb(ff9e64) 45deg" # Orange/Blue for Master
elif [ "$CURRENT_LAYOUT" = "master" ]; then
    NEW_LAYOUT="scrolling"
    BORDER_COLOR="rgb(30beee) rgb(c6a0f6) 45deg" # Purple/Blue for Scrolling
else 
    NEW_LAYOUT="dwindle"
    BORDER_COLOR="rgb(30beee) rgb(00ee8f) 45deg" # Green/Blue for Dwindle
fi

# Inject the new configuration into Lua using double quotes to allow Bash variables
hyprctl eval "hl.config({ general = { layout = \"$NEW_LAYOUT\", col = { active_border = \"$BORDER_COLOR\" } } })"

# Force the property refresh instantly
hyprctl eval 'hl.exec_scheduled_prop_refresh_immediately()'

# Send notification
notify-send -t 3000 -i dialog-information "Workspace Layout" "Set to $NEW_LAYOUT"
