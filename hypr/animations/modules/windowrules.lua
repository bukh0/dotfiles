-- ~/.config/hypr/windowrules.lua

hl.config({
    windowrulev2 = {
        -- Global rules
        "suppressevent maximize, class:.*",
        
        -- Floating utility windows
        "float, class:^(pavucontrol)$",
        "float, class:^(blueman-manager)$",
        "float, class:^(nm-connection-editor)$",
        
        -- Transparency for your core apps
        "opacity 0.90 0.90, class:^(kitty)$",
        "opacity 0.95 0.95, class:^(firefox)$",
        "opacity 0.90 0.90, class:^(dolphin)$",
        "opacity 0.95 0.95, class:^(discord)$"
    }
})
