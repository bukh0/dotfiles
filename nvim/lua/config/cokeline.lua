local M = {}
local state = require("utils.state")
local enabled = state.read("cokeline.state", "1") ~= "0"
local MINIMUM_BUFFERS = 2

local function refresh()
  local buffers = require("cokeline.buffers").get_visible()
  vim.o.showtabline = enabled and #buffers >= MINIMUM_BUFFERS and 2 or 0
  vim.cmd.redrawtabline()
end

function M.toggle()
  enabled = not enabled
  state.write("cokeline.state", enabled and "1" or "0")
  refresh()
  vim.notify("Cokeline " .. (enabled and "enabled" or "disabled"))
end

function M.cycle(step)
  -- Hidden tablines do not redraw, so refresh navigation's buffer cache.
  require("cokeline.buffers").get_visible()
  require("cokeline.mappings").by_step("focus", step)
end

function M.setup()
  -- Replace Cokeline's automatic show-on-buffer-add behavior so opening a
  -- file cannot undo the user's choice to hide the bar.
  vim.api.nvim_clear_autocmds({ group = "cokeline_autocmds", event = { "VimEnter", "BufAdd" } })
  local group = vim.api.nvim_create_augroup("CokelineVisibility", { clear = true })
  local pending = false
  vim.api.nvim_create_autocmd({ "VimEnter", "BufAdd", "BufDelete", "BufEnter" }, {
    group = group,
    callback = function()
      if pending then return end
      pending = true
      vim.schedule(function()
        pending = false
        refresh()
      end)
    end,
  })
  vim.api.nvim_create_user_command("ToggleCokeline", M.toggle, { desc = "Toggle Cokeline buffer bar" })
  refresh()
end

return M
