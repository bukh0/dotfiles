-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃      @ ; Waybar blur                                             ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.0 })
-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃      @ ; Rofi                                                    ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
hl.layer_rule({ match = { namespace = "rofi" }, blur = false, ignore_alpha = 0.0 })

-- Frosted surfaces belong to the glass profile. Preserve the normal blur
-- preference when another profile is selected.
local qs_cache = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")
local qs_profile = io.open(qs_cache .. "/quickshell_current_bar", "r")
local qs_glass = qs_profile and qs_profile:read("*l") == "glass"
if qs_profile then qs_profile:close() end
if qs_glass then hl.config({ decoration = { blur = { enabled = true } } }) end
hl.layer_rule({ match = { namespace = "quickshell-glass-.*" }, blur = true, ignore_alpha = 0.1 })
