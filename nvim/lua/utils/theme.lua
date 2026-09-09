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

-- Hardcoded last-resort colors for any slot a colorscheme leaves undefined
-- (e.g. minimal/light themes that don't set an explicit Normal background).
-- Without these, a nil bg/fg passed to nvim_set_hl means "don't override
-- this group," which causes inconsistent per-cell compositing in tablines —
-- exactly the patchy background-color issue seen across theme switches.
local function fallback_base()
  return vim.o.background == "light" and "#f2f2f2" or "#1e1e2e"
end

local function fallback_fg()
  return vim.o.background == "light" and "#2e2e2e" or "#cdd6f4"
end

function M.colors()
  local base = hl("Normal", "bg") or fallback_base()
  local fg = hl("Normal") or hl("Statement") or fallback_fg()

  return {
    bg = "NONE",
    fg = fg,
    dim = hl("Comment") or fg,
    base = base,
    accent = hl("Function") or hl("Special") or hl("Identifier") or fg,
    blue = hl("DiagnosticInfo") or hl("Function") or fg,
    green = hl("DiagnosticOk") or hl("String") or fg,
    yellow = hl("DiagnosticWarn") or fg,
    red = hl("DiagnosticError") or fg,
    peach = hl("Constant") or hl("Number") or fg,
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
