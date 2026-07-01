-- ~/.config/hypr/hyprland.lua

-- ==========================================
-- Global Variables
-- ==========================================
Terminal    = "kitty"
FileManager = "thunar"
Menu        = "rofi -show drun"
Browser     = "zen-browser"
Message     = "vesktop"

RofiWallpick    = os.getenv("HOME") .. "/.config/rofi/minimal/wallpaper.rasi"
RofiAppLauncher = os.getenv("HOME") .. "/.config/rofi/minimal/config.rasi"
-- ~/.config/hypr/hyprland.lua
-- BARE MINIMUM ENTRY POINT

-- 1. Hardware & Environment
require("environment")
require("input")

-- 2. Visuals & Rules (Static, no dynamic themes)
require("looknfeel")
require("windowrules")

-- 3. Binds & Startup
require("keybinds")
require("autostart")
