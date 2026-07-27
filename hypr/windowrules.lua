-- ~/.config/hypr/modules/windowrules.lua

-- Global rules
hl.window_rule({ match = { class = ".*" },                  suppress_event = "maximize" })

-- Floating utility windows
hl.window_rule({ match = { class = "pavucontrol" },         float = true })
hl.window_rule({ match = { class = "blueman-manager" },     float = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })

-- Transparency
hl.window_rule({ match = { class = "kitty" },               opacity = 1.0 })
hl.window_rule({ match = { class = "firefox" },             opacity = 1.0 })
hl.window_rule({ match = { class = "dolphin" },             opacity = 0.90 })
hl.window_rule({ match = { class = "discord" },             opacity = 1.0 })
