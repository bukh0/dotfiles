hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon &")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("nohup swayosd-server &")

-- Automatic sunrise/sunset transition
    hl.exec_cmd("wlsunset -l -25.74 -L 28.18 -t 4500 -T 6500 &")
    hl.exec_cmd("hypridle &")
--    hl.exec_cmd("waybar")
--    hl.exec_cmd("swaync")
    hl.exec_cmd("quickshell &")
end)
