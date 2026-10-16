require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("config.transparency").setup()
require("config.winbar").setup()

local state = require("utils.state")
local FALLBACK = "ayu-dark"
local name = state.read("colorscheme.state", FALLBACK)
if not pcall(vim.cmd.colorscheme, name) then
  vim.schedule(function()
    vim.notify(("colorscheme '%s' failed to load, falling back to %s"):format(name, FALLBACK), vim.log.levels.WARN)
  end)
  if not pcall(vim.cmd.colorscheme, FALLBACK) then
    pcall(vim.cmd.colorscheme, "habamax")
  end
end
