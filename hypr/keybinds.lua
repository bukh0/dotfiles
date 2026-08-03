-- ~/.config/hypr/modules/keybinds.lua
local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "rofi -show drun"
local message     = "discord"
local mod         = "SUPER"

-- Applications
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("zen-browser"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd(message))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("spotify"))
hl.bind(mod .. " + Y", hl.dsp.exec_cmd("kitty -e yazi"))
hl.bind(mod .. " + period", hl.dsp.exec_cmd("bemoji -t"))

-- Window Management
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exec_cmd("wlogout"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client --close-latest"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + M",  hl.dsp.exit())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("uwsm stop"))

-- Screenshot
hl.bind(mod .." + CTRL + S", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png'))
hl.bind(mod .." + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png'))

-- Theming & Scripts
hl.bind(mod .. " + B", hl.dsp.exec_cmd("~/.scripts/toggle.blur.sh"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("~/.scripts/wallpick.sh"))
hl.bind(mod .. " + T", hl.dsp.exec_cmd("~/.scripts/theme.switcher.sh"))
hl.bind(mod .. " + H", hl.dsp.exec_cmd("~/.scripts/configs.sh"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd([[bash -c "pkill -x wlsunset || wlsunset -l -25.74 -L 28.18 -t 4500 -T 6500 &"]]))
hl.bind(mod .. " + G", hl.dsp.exec_cmd("~/.scripts/gamemode-toggle.sh"))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.scripts/toggle-performance.sh"))
hl.bind(mod .. " + J", hl.dsp.exec_cmd("~/.scripts/toggleLayout.sh"))

-- Waybar & Custom Toggles
hl.bind(mod .. " + ALT + 9", hl.dsp.exec_cmd("~/.scripts/toggle_waybar.sh"))
hl.bind(mod .. " + ALT + 8", hl.dsp.exec_cmd("~/user_scripts/wayclick/dusky_wayclick.sh"))
hl.bind(mod .. " + ALT + 0", hl.dsp.exec_cmd("~/.scripts/toggle_quickshell.sh"))

-- Audio & Brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true})
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"), {locked = true})
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("/usr/local/bin/mute-toggle.sh"),    { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("/usr/local/bin/micmute-toggle.sh"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), {locked = true})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), {locked = true})

-- Move Focus
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "d" }))

-- Workspaces 1-10
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,               hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i,       hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Scratchpad
hl.bind(mod .. " + S",         hl.dsp.focus({ workspace = "special:magic" }))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
-- Mouse window controls
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- Media Controls (locked - work on lockscreen)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),        { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"),  { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),    { locked = true })
