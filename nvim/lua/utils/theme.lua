local M = {}

-- Reads a color straight from Neovim's currently loaded colorscheme.
-- Fully independent of matugen / system theme — only responds to `:colorscheme X`.
local function hl(name, attr)
  attr = attr or "fg"
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or not h or not h[attr] then
    return nil
  end
  return string.format("#%06x", h[attr])
end

function M.colors()
  return {
    bg = "NONE",
    fg = hl("Normal") or hl("Statement"),
    dim = hl("Comment"),
    base = hl("Normal", "bg"),
    accent = hl("Function") or hl("Special") or hl("Identifier"),
    blue = hl("DiagnosticInfo") or hl("Function"),
    green = hl("DiagnosticOk") or hl("String"),
    yellow = hl("DiagnosticWarn"),
    red = hl("DiagnosticError"),
    peach = hl("Constant") or hl("Number"),
  }
end

-- Fixes the default white/bright WinSeparator and FloatBorder highlights,
-- which most colorschemes leave unstyled. Derives from the same palette
-- as bufferline/lualine so borders match rather than standing out.
function M.apply_ui_highlights()
  local c = M.colors()
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = c.dim, bg = "NONE" })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = c.dim, bg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "Pmenu", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "PmenuSel", { bg = c.accent, fg = c.base })
end

-- Debounced ColorScheme listener — collapses rapid-fire events (e.g. Telescope's
-- live colorscheme preview via <leader>uC) into a single rebuild after things settle.
-- Uses a generation counter instead of raw timer handles to avoid double-close races
-- when ColorScheme fires multiple times within one event-loop tick.
function M.on_colorscheme(callback, delay)
  delay = delay or 80
  local generation = 0
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      generation = generation + 1
      local this_gen = generation
      vim.defer_fn(function()
        if this_gen == generation then
          callback()
          M.apply_ui_highlights()
        end
      end, delay)
    end,
  })
end

return M
