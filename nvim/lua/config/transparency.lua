local M = {}

local state_file = vim.fn.stdpath("state") .. "/transparency.state"
local transparent = false

local function save_state()
  local f = io.open(state_file, "w")
  if f then
    f:write(transparent and "1" or "0")
    f:close()
  end
end

local function load_state()
  local f = io.open(state_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    return content == "1"
  end
  return false
end

local function apply(silent)
  if transparent then
    vim.cmd([[
      highlight Normal guibg=NONE ctermbg=NONE
      highlight NormalNC guibg=NONE ctermbg=NONE
      highlight SignColumn guibg=NONE ctermbg=NONE
      highlight EndOfBuffer guibg=NONE ctermbg=NONE
    ]])
    require("utils.theme").apply_ui_highlights()
    if not silent then print("Transparency enabled") end
  else
    vim.cmd("colorscheme ayu-dark")
    if not silent then print("Transparency disabled") end
  end
end

local function toggle_transparency()
  transparent = not transparent
  apply(false)
  save_state()
end

function M.setup()
  transparent = load_state()
  if transparent then
    -- defer so it runs after the colorscheme has loaded on startup
    vim.schedule(function()
      apply(true)
    end)
  end
end

vim.api.nvim_create_user_command("ToggleTransparency", toggle_transparency, {})
vim.keymap.set("n", "<leader>ut", toggle_transparency, { desc = "Toggle background transparency" })

return M
