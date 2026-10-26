-- ~/.config/hypr/environment.lua

-- Toolkit Backend Variables
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
-- Cursor theme and size follow GTK Settings through gtk-cursor-sync.service.

-- Hardware Configuration (Consolidated)
hl.config({
    cursor = {
        enable_hyprcursor = false, -- Use Xcursor themes selected in GTK Settings
        no_hardware_cursors = false,
        no_break_fs_vrr = true,
        warp_on_change_workspace = false,
        sync_gsettings_theme = false, -- nwg-look/gsettings is the source; Hyprland must not write back
    }
})
