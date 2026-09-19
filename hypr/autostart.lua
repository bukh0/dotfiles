-- ~/.config/hypr/autostart.lua

hl.on("hyprland.start", function()
  -- Session environment for D-Bus / systemd-launched apps
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

  -- Core services
  hl.exec_cmd("awww-daemon &")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("nohup swayosd-server &")
  hl.exec_cmd("hypridle &")
  hl.exec_cmd("quickshell &")
  -- hl.exec_cmd("waybar")
  -- hl.exec_cmd("swaync")

  -- Automatic sunrise/sunset transition
  hl.exec_cmd("wlsunset -l -25.74 -L 28.18 -t 4500 -T 6500 &")

  -- Clipboard history (guard on wl-paste: cliphist itself is short-lived)
  hl.exec_cmd("pidof wl-paste || (wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store &)")
end)
