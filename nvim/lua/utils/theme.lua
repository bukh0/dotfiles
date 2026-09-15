local M = {}
local state = require("utils.state")

M.transparent = state.read("transparency.state", "0") == "1"

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
local function fallback_base()
  return vim.o.background == "light" and "#f2f2f2" or "#1e1e2e"
end

local function fallback_fg()
  return vim.o.background == "light" and "#2e2e2e" or "#cdd6f4"
end

function M.colors()
  local solid_base = hl("Normal", "bg") or fallback_base()
  local fg = hl("Normal") or hl("Statement") or fallback_fg()

  return {
    bg = "NONE",
    fg = fg,
    dim = hl("Comment") or fg,
    base = M.transparent and "NONE" or solid_base,
    solid_base = solid_base,
    accent = hl("Function") or hl("Special") or hl("Identifier") or fg,
    blue = hl("DiagnosticInfo") or hl("Function") or fg,
    green = hl("DiagnosticOk") or hl("String") or fg,
    yellow = hl("DiagnosticWarn") or fg,
    red = hl("DiagnosticError") or fg,
    peach = hl("Constant") or hl("Number") or fg,
  }
end

-- Fixes the default white/bright WinSeparator and FloatBorder highlights,
-- and applies transparency to Normal/NormalNC/SignColumn/EndOfBuffer.
--
-- Uses fetch-merge-reapply rather than a raw nvim_set_hl(0, group, {...})
-- call: nvim_set_hl fully REPLACES a highlight group's definition, so
-- writing only {fg=..., bg=...} would silently drop any italic/bold/
-- undercurl/sp attributes the active colorscheme set on that group (some
-- schemes do style FloatBorder/WinSeparator beyond plain fg/bg). Fetching
-- first and only overwriting fg/bg preserves everything else.
local function override(group, bg_color, fg_color)
  local existing = vim.api.nvim_get_hl(0, { name = group, link = false })
  existing.bg = bg_color
  if fg_color then
    existing.fg = fg_color
  end
  vim.api.nvim_set_hl(0, group, existing)
end

function M.apply_ui_highlights()
  local c = M.colors()
  override("Normal", c.base, c.fg)
  override("NormalNC", c.base, c.fg)
  override("SignColumn", c.base)
  override("EndOfBuffer", c.base)
  override("WinSeparator", "NONE", c.dim)
  override("FloatBorder", "NONE", c.dim)
  override("NormalFloat", "NONE")
  override("Pmenu", "NONE")
  -- use solid_base, not base — base can be "NONE" now, which is invalid
  -- as a foreground color and would leave PmenuSel illegible
  override("PmenuSel", c.accent, c.solid_base)
end

-- Debounced ColorScheme listener — collapses rapid-fire events (e.g. Telescope's
-- live colorscheme preview via <leader>uC) into a single rebuild after things settle.
-- Uses a generation counter instead of raw timer handles to avoid double-close races
-- when ColorScheme fires multiple times within one event-loop tick.
-- pcall-wrapped so one broken theme's callback can't wedge every other
-- listener (bufferline, lualine, etc.) registered through this function.
function M.on_colorscheme(callback, delay)
  delay = delay or 80
  local generation = 0
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      generation = generation + 1
      local this_gen = generation
      vim.defer_fn(function()
        if this_gen == generation then
          local ok, err = pcall(callback)
          if not ok then
            vim.notify("theme rebuild callback failed: " .. tostring(err), vim.log.levels.WARN)
          end
          pcall(M.apply_ui_highlights)
        end
      end, delay)
    end,
  })
end

-- Persist whichever colorscheme is actually active whenever it changes, so
-- colorscheme.state (read by plugins/theme.lua on startup) reflects the last
-- one you really picked. vim.g.colors_name only gets set by Neovim after a
-- colorscheme load succeeds, so a failed/erroring load never reaches this
-- callback with a new name to persist.
M.on_colorscheme(function()
  local name = vim.g.colors_name
  if name and name ~= "" then
    state.write("colorscheme.state", name)
  end
end)

-- Toggle transparency without touching :colorscheme. Flips `base` between
-- "NONE" and the real bg, applies it immediately, then fires a synthetic
-- ColorScheme event so every on_colorscheme() consumer rebuilds against the
-- new bg — this module doesn't need to know who's listening.
function M.set_transparent(value)
  M.transparent = value
  state.write("transparency.state", value and "1" or "0")
  M.apply_ui_highlights()
  vim.api.nvim_exec_autocmds("ColorScheme", {})
end

return M
