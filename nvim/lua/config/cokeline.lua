local M = {}
local state = require("utils.state")
local enabled = state.read("cokeline.state", "1") ~= "0"
local MINIMUM_BUFFERS = 2

function M.is_file_buffer(buf)
  return vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "netrw"
end

local function refresh()
  local buffers = vim.tbl_filter(
    function(buf) return M.is_file_buffer(buf.bufnr) end,
    vim.fn.getbufinfo({ buflisted = 1 })
  )
  local visibility = enabled and #buffers >= MINIMUM_BUFFERS and 2 or 0
  if vim.o.showtabline ~= visibility then vim.o.showtabline = visibility end
  vim.cmd.redrawtabline()
end

function M.toggle()
  enabled = not enabled
  state.write("cokeline.state", enabled and "1" or "0")
  refresh()
  vim.notify("Cokeline " .. (enabled and "enabled" or "disabled"))
end

function M.cycle(step)
  -- Evaluate the configured tabline through Neovim so Cokeline refreshes its
  -- navigation state even when hidden, without calling its internal modules.
  vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true })
  local mapping = step < 0 and "<Plug>(cokeline-focus-prev)" or "<Plug>(cokeline-focus-next)"
  vim.api.nvim_feedkeys(vim.keycode(mapping), "mi", false)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("CokelineVisibility", { clear = true })
  local pending = false
  vim.api.nvim_create_autocmd({ "VimEnter", "BufAdd", "BufDelete", "BufEnter", "FileType" }, {
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
  -- Cokeline may set showtabline when buffers are added. Enforce our policy
  -- without deleting or depending on the names of the plugin's autocmds.
  -- OptionSet is non-recursive; the scheduled events above also cover startup
  -- (when OptionSet is suppressed) and deletion (before buflisted is cleared).
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "showtabline", "buflisted", "buftype" },
    callback = refresh,
  })
  vim.api.nvim_create_user_command("ToggleCokeline", M.toggle, { desc = "Toggle Cokeline buffer bar" })
  refresh()
end

return M
