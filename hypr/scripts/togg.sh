---------------------------------
---- WORKSPACE LAYOUT TOGGLE ----
---------------------------------
local function update_border_colors(layout)
if layout == "scrolling" then
hl.config({
general = {
border_size = 2,
col = {
active_border = {
colors = { "#30beee", "#c6a0f6" },
angle = 45,
},
inactive_border = "#444444",
},
},
})
else
hl.config({
general = {
border_size = 2,
col = {
active_border = {
colors = { "#30beee", "#00ee8f" },
angle = 45,
},
inactive_border = "#444444",
},
},
})
end
end
hl.on("workspace.active", function(ws)
if ws then
update_border_colors(ws.tiled_layout)
end
end)
local mainMod = "SUPER"
hl.bind(mainMod .. " + SHIFT + T", function()
local ws = hl.get_active_workspace()
if not ws then
return
end
local new_layout = ws.tiled_layout == "dwindle" and "scrolling" or "dwindle"
hl.workspace_rule({
workspace = tostring(ws.id),
layout = new_layout,
})
update_border_colors(new_layout)
hl.notification.create({
text = " 󱂬    Workspace layout set to " .. new_layout,
duration = 3000,
icon = 5,
})
end)
