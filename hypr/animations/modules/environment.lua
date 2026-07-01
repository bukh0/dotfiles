-- ~/.config/hypr/environment.lua

-- Toolkit Backend Variables
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")

-- Theming Variables
hl.env("GTK_THEME", "adw-gtk3-dark:dark")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Hardware Configuration (The Fix)
hl.config({
    cursor = {
        no_hardware_cursors = false
    }
})
