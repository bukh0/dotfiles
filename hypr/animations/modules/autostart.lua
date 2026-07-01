-- ~/.config/hypr/modules/autostart.lua
-- BARE MINIMUM STARTUP

hl.config({
    exec_once = {
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
        "/usr/lib/polkit-kde-authentication-agent-1",
        "waybar",
        "swaync"
    }
})
