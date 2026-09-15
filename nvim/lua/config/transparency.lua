local theme = require("utils.theme")

local function toggle_transparency()
  theme.set_transparent(not theme.transparent)
  print(theme.transparent and "Transparency enabled" or "Transparency disabled")
end

local M = {}

function M.setup()
  if theme.transparent then
    vim.schedule(function()
      theme.apply_ui_highlights()
    end)
  end
end

vim.api.nvim_create_user_command("ToggleTransparency", toggle_transparency, {})
vim.keymap.set("n", "<leader>ut", toggle_transparency, { desc = "Toggle background transparency" })

return M
