-- ~/.config/hypr/modules/keybinds.lua

-- Define your default applications here
local terminal = "kitty"
local fileManager = "thunar" -- Change to dolphin, nemo, etc. if needed
local menu = "rofi -show drun"
local message = "discord" -- Change to your preferred messaging app

-- 1. Initialize empty tables for our binds
local binds = {}
local binds_locked = {} -- For bindl (works when screen is locked)
local binds_mouse = {}  -- For bindm (mouse interactions)

-- 2. Populate standard keybinds
binds = {
    -- Applications
    "SUPER SHIFT, M, exit",
    "SUPER, Return, exec, " .. terminal,
    "SUPER, E, exec, " .. fileManager,
    "SUPER, SPACE, exec, " .. menu,
    "SUPER, W, exec, zen-browser",
    "SUPER, A, exec, " .. message,
    "SUPER, P, exec, spotify",

    -- Window Management
    "SUPER, Q, killactive",
    "SUPER, M, exec, wlogout",
    "SUPER, L, exec, hyprlock",
    "SUPER, J, layoutmsg, togglesplit",
    "SUPER, V, togglefloating",
    "SUPER, N, exec, swaync-client --close-latest",
    "SUPER, F, exec, ~/.scripts/fullscreen_toggle.sh",

    -- Screenshot (Using single quotes so the internal double quotes parse safely)
    'CTRL, S, exec, grim -g "$(slurp)" ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png',

    -- Theming & Scripts
    "SUPER, B, exec, ~/.scripts/toggle.blur.sh",
    "SUPER, T, exec, ~/.config/hypr/scripts/theme-switch.sh",
    "SUPER, H, exec, ~/.scripts/configs.sh",

    -- Waybar & Custom Toggles
    "ALT, 9, exec, ~/.scripts/toggle_waybar.sh",
    "ALT, 8, exec, ~/user_scripts/wayclick/dusky_wayclick.sh",

    -- Audio & Brightness (SwayOSD)
    ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise",
    ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower",
    ", XF86AudioMute, exec, ~/.scripts/audio-mute-toggle.sh",
    ", XF86AudioMicMute, exec, ~/.scripts/mic-toggle.sh",
    ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise",
    ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower",

    -- Move Focus
    "SUPER, left, movefocus, l",
    "SUPER, right, movefocus, r",
    "SUPER, up, movefocus, u",
    "SUPER, down, movefocus, d",

    -- Workspace 10
    "SUPER, 0, workspace, 10",
    "SUPER SHIFT, 0, movetoworkspace, 10",

    -- Scratchpads
    "SUPER, S, togglespecialworkspace, magic",
    "SUPER SHIFT, S, movetoworkspace, special:magic",

    -- Scroll Workspaces
    "SUPER, mouse_down, workspace, e+1",
    "SUPER, mouse_up, workspace, e-1",
}

-- 3. Loop Workspaces 1-9 (Injecting into the binds table)
for i = 1, 9 do
    table.insert(binds, "SUPER, " .. tostring(i) .. ", workspace, " .. tostring(i))
    table.insert(binds, "SUPER SHIFT, " .. tostring(i) .. ", movetoworkspace, " .. tostring(i))
end

-- 4. Populate Media Controls (bindl)
binds_locked = {
    ", XF86AudioNext, exec, playerctl next",
    ", XF86AudioPause, exec, playerctl play-pause",
    ", XF86AudioPlay, exec, playerctl play-pause",
    ", XF86AudioPrev, exec, playerctl previous",
}

-- 5. Populate Mouse Binds (bindm)
binds_mouse = {
    "SUPER, mouse:272, movewindow",
    "SUPER, mouse:273, resizewindow",
}

-- 6. Pass everything directly to Hyprland
hl.config({
    bind = binds,
    bindl = binds_locked,
    bindm = binds_mouse
})
