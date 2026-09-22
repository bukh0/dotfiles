local M = {}
local state = require("utils.state")

M.transparent = state.read("transparency.state", "0") == "1"

local DEBOUNCE_MS = 80

local function hl(name, attr)
  attr = attr or "fg"
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or not h or not h[attr] then
    return nil
  end
  return string.format("#%06x", h[attr])
end

local function fallback_base()
  return vim.o.background == "light" and "#f2f2f2" or "#1e1e2e"
end

local function fallback_fg()
  return vim.o.background == "light" and "#2e2e2e" or "#cdd6f4"
end

-- Cached palette, invalidated only when the debounced dispatcher below fires
-- or transparency is toggled — not recomputed on every call. Safe now for
-- anything (cokeline's get_color included) to call M.colors() directly on
-- every redraw instead of keeping its own local copy.
local cached_colors = nil

local function invalidate_colors()
  cached_colors = nil
end

function M.colors()
  if cached_colors then
    return cached_colors
  end
  local solid_base = hl("Normal", "bg") or fallback_base()
  local fg = hl("Normal") or hl("Statement") or fallback_fg()

  cached_colors = {
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
  return cached_colors
end

local function override(group, bg_color, fg_color)
  local existing = vim.api.nvim_get_hl(0, { name = group, link = false })
  local updates = { bg = bg_color }
  if fg_color then
    updates.fg = fg_color
  end
  vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", existing, updates))
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
  override("PmenuSel", c.accent, c.solid_base)
end

-- Single debounced ColorScheme dispatcher. Before: every M.on_colorscheme()
-- caller registered its own autocmd + its own generation counter + its own
-- vim.defer_fn, so apply_ui_highlights() and the colorscheme.state write ran
-- once PER SUBSCRIBER instead of once per real change (toggling transparency
-- rebuilt highlights twice and wrote the same name to disk twice). Now
-- there's exactly one autocmd/one debounce cycle; subscribers are just
-- appended to a list and run together once it settles.
local subscribers = {}
local generation = 0

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    generation = generation + 1
    local this_gen = generation
    vim.defer_fn(function()
      if this_gen ~= generation then
        return
      end
      invalidate_colors()
      for _, callback in ipairs(subscribers) do
        local ok, err = pcall(callback)
        if not ok then
          vim.notify("theme rebuild callback failed: " .. tostring(err), vim.log.levels.WARN)
        end
      end
      pcall(M.apply_ui_highlights)
    end, DEBOUNCE_MS)
  end,
})

function M.on_colorscheme(callback)
  table.insert(subscribers, callback)
end

-- Persist the active colorscheme, deduped against what's already on disk so
-- set_transparent()'s synthetic ColorScheme event (fired below) doesn't
-- rewrite the same name every toggle.
local last_persisted = state.read("colorscheme.state", nil)
M.on_colorscheme(function()
  local name = vim.g.colors_name
  if name and name ~= "" and name ~= last_persisted then
    state.write("colorscheme.state", name)
    last_persisted = name
  end
end)

function M.set_transparent(value)
  M.transparent = value
  state.write("transparency.state", value and "1" or "0")
  invalidate_colors()
  -- The ColorScheme autocmd handler already calls apply_ui_highlights()
  -- after debouncing, so no need to call it explicitly here.
  vim.api.nvim_exec_autocmds("ColorScheme", {})
end

return M
