local M = {}

local function esc(s)
  return (s:gsub("%%", "%%%%"))
end

-- Real file windows only: skips floats, terminals, explorer, help, quickfix.
local function is_file_win(win)
  if not vim.api.nvim_win_is_valid(win) then return false end
  local config = vim.api.nvim_win_get_config(win)
  if config.relative ~= "" or config.external then return false end
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
end

function M.render()
  local win = vim.g.statusline_winid
  if not win or not vim.api.nvim_win_is_valid(win) then return "" end
  local buf = vim.api.nvim_win_get_buf(win)
  local path = vim.api.nvim_buf_get_name(buf)
  local tail = path == "" and "[No Name]" or vim.fn.fnamemodify(path, ":t")
  local parent = path == "" and "" or vim.fn.fnamemodify(path, ":h:t")
  local focused = win == vim.api.nvim_get_current_win()

  local icon = ""
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    icon = devicons.get_icon(tail, vim.fn.fnamemodify(tail, ":e"), { default = true }) or ""
  end

  local name_hl = focused and "%#Title#" or "%#Comment#"
  local out = { " ", name_hl, icon, " ", esc(tail) }
  if parent ~= "" then
    table.insert(out, "%#Comment# " .. esc(parent) .. "/")
  end

  local counts = vim.diagnostic.count(buf)
  local errors = counts[vim.diagnostic.severity.ERROR] or 0
  local warns = counts[vim.diagnostic.severity.WARN] or 0
  if errors > 0 then
    table.insert(out, "%#DiagnosticError# 󰅚 " .. errors)
  elseif warns > 0 then
    table.insert(out, "%#DiagnosticWarn# 󰀪 " .. warns)
  end
  if vim.bo[buf].modified then
    table.insert(out, "%#DiagnosticWarn# ●")
  end
  return table.concat(out)
end

-- %! supplies g:statusline_winid and keeps the actual focused window as
-- current; both are needed to distinguish active and inactive winbars.
local EXPR = "%!v:lua.require'config.winbar'.render()"

function M.update()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local count = #vim.tbl_filter(is_file_win, wins)
  for _, win in ipairs(wins) do
    local file_win = is_file_win(win)
    local cur = vim.wo[win].winbar
    if count > 1 and file_win then
      if cur ~= EXPR then vim.wo[win].winbar = EXPR end
    elseif cur == EXPR then
      -- Only clear our own bar; special windows may have plugin headers.
      vim.wo[win].winbar = ""
    end
    if file_win then
      vim.wo[win].cursorline = win == vim.api.nvim_get_current_win()
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("user_winbar", { clear = true })
  vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter", "TabEnter", "FileType" }, {
    group = group,
    callback = M.update,
  })
  -- The closing window is still listed during WinClosed.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function() vim.schedule(M.update) end,
  })
  vim.api.nvim_create_autocmd({ "WinEnter", "DiagnosticChanged", "BufModifiedSet", "BufFilePost" }, {
    group = group,
    callback = function() vim.cmd("redrawstatus!") end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      if is_file_win(0) then vim.wo.cursorline = false end
    end,
  })
  M.update()
end

return M
