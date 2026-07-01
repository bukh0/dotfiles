-- ~/.config/hypr/themes/loader.lua

local state_file = os.getenv("HOME") .. "/.config/hypr/.current-theme"
local f = io.open(state_file, "r")
local theme = f and f:read("*l") or "catppuccin"
if f then f:close() end

local status, result

if theme == "matugen" then
    status, result = pcall(require, "themes.matugen.colours")
else
    -- Looks directly in the themes folder instead of themes.presets
    status, result = pcall(require, "themes." .. theme)
end

-- Failsafe: Loads Catppuccin directly from the themes folder
if not status then
    return require("themes.catppuccin")
end

return result
