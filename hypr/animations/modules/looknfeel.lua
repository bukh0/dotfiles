-- ~/.config/hypr/modules/looknfeel.lua
-- STATIC COLORS ONLY

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = "rgb(33ccff)",   -- Solid blue, no gradient
            inactive_border = "rgb(595959)", -- Solid grey
        },
        layout = "dwindle"
    },
    decoration = {
        rounding = 10,
        blur = {
            enabled = false
        },
        shadow = {
            enabled = false
        }
    }
})
