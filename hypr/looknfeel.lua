-- ~/.config/hypr/modules/looknfeel.lua
-- STATIC COLORS ONLY

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 0,
        border_size = 1,
        col = {
            --active_border = "rgb(33ccff)",   -- Solid blue, no gradient
            inactive_border = "rgb(595959)", -- Solid grey
        },
        layout = "dwindle"
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = false,
            passes = 3,
            size = 7,
            noise = 0.02,
            contrast = 1.0,
            brightness = 1.0,
        },
        shadow = {
            enabled = false
        }
    }
})
