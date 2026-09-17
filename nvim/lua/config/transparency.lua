local theme = require("utils.theme")

local M = {}

local function toggle()
  theme.set_transparent(not theme.transparent)
  vim.notify(
    theme.transparent and "Transparency enabled" or "Transparency disabled",
    vim.log.levels.INFO,
    { title = "Transparency" }
  )
end

function M.setup()
  if M._done then
    return
  end
  M._done = true

  vim.api.nvim_create_user_command("ToggleTransparency", toggle, {
    desc = "Toggle background transparency",
  })

  local ok, Snacks = pcall(require, "snacks")
  if ok and Snacks.toggle then
    Snacks.toggle({
      name = "Transparency",
      get = function() return theme.transparent end,
      set = function(state) theme.set_transparent(state) end,
    }):map("<leader>ut")
  else
    vim.keymap.set("n", "<leader>ut", toggle, { desc = "Toggle background transparency" })
  end

  -- utils.theme.on_colorscheme already calls apply_ui_highlights after every
  -- (debounced) theme change — no separate ColorScheme autocmd needed here.
  if theme.transparent then
    vim.schedule(theme.apply_ui_highlights)
  end
end

return M
