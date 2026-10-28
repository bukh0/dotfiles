local M = {}
local state = require("utils.state")

M.transparent = state.read("transparency.state", "0") == "1"

local DEBOUNCE_MS = 80

-- Some themes normalize g:colors_name (e.g. Monokai Pro's filters).
-- Keep the requested variant so toggling/restarting does not reset it.
local active_colorscheme = vim.g.colors_name
local last_solid_base
local cached_colors
vim.api.nvim_create_autocmd("ColorSchemePre", {
  callback = function(event)
    last_solid_base = nil
    cached_colors = nil
    if event.match ~= "" then
      active_colorscheme = event.match
    end
  end,
})

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

-- Cached palette, invalidated when a theme loads or ColorScheme fires,
-- or transparency is toggled — not recomputed on every call. Safe for
-- anything (cokeline's get_color included) to call M.colors() directly on
-- every redraw instead of keeping its own local copy.
local function invalidate_colors()
  cached_colors = nil
end

function M.colors()
  if cached_colors then
    return cached_colors
  end
  local raw_bg = hl("Normal", "bg")
  if raw_bg then last_solid_base = raw_bg end
  local solid_base = last_solid_base or fallback_base()
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
  override("WinBar", c.base, c.fg)
  override("WinBarNC", c.base, c.dim)
  override("TabLine", "NONE")
  override("TabLineFill", "NONE")
  override("SignColumn", c.base)
  override("EndOfBuffer", c.base)
  override("WinSeparator", "NONE", c.dim)
  override("FloatBorder", c.base, c.dim)
  override("NormalFloat", c.base)
  override("Pmenu", c.base)
  override("PmenuSel", c.accent, c.solid_base)
end

-- Apply highlights immediately to avoid opaque frames during theme changes.
-- Debounce subscribers (including state persistence) until previews settle.
local subscribers = {}
local generation = 0

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    invalidate_colors()
    M.apply_ui_highlights()
    generation = generation + 1
    local this_gen = generation
    vim.defer_fn(function()
      if this_gen ~= generation then
        return
      end
      for _, callback in ipairs(subscribers) do
        local ok, err = pcall(callback)
        if not ok then
          vim.notify("theme rebuild callback failed: " .. tostring(err), vim.log.levels.WARN)
        end
      end
    end, DEBOUNCE_MS)
  end,
})

function M.on_colorscheme(callback)
  table.insert(subscribers, callback)
end

-- Persist the active colorscheme, deduped against what's already on disk so
-- transparency toggles do not rewrite the same name on every reload.
local previewing = false
local last_persisted = state.read("colorscheme.state", nil)
M.on_colorscheme(function()
  if previewing then return end
  local name = active_colorscheme or vim.g.colors_name
  if name and name ~= "" and name ~= last_persisted then
    if state.write("colorscheme.state", name) then
      last_persisted = name
    end
  end
end)

-- Own the preview lifecycle so cancellation restores the exact theme variant.
function M.pick_colorscheme(opts)
  if previewing then return end
  local original = active_colorscheme or vim.g.colors_name or "default"
  local background = vim.o.background
  local selected
  previewing = true
  local ok, picker = pcall(Snacks.picker.colorschemes, vim.tbl_extend("force", opts or {}, {
    config = function()
      -- Snacks also calls this when resuming a closed picker.
      original = active_colorscheme or vim.g.colors_name or "default"
      background = vim.o.background
      selected = nil
      previewing = true
    end,
    preview = function(ctx)
      vim.schedule(function()
        if not ctx.picker.closed and ctx.item and ctx.item.text then
          vim.o.background = background
          pcall(vim.cmd.colorscheme, ctx.item.text)
        end
      end)
      Snacks.picker.preview.file(ctx)
    end,
    confirm = function(p, item)
      selected = item and item.text
      p:close()
    end,
    on_close = function()
      vim.schedule(function()
        vim.o.background = background
        previewing = false
        local applied, err = pcall(vim.cmd.colorscheme, selected or original)
        if not applied then
          vim.o.background = background
          pcall(vim.cmd.colorscheme, original)
          vim.notify("Colorscheme failed: " .. tostring(err), vim.log.levels.WARN)
        end
      end)
    end,
  }))
  if not ok then
    previewing = false
    vim.o.background = background
    pcall(vim.cmd.colorscheme, original)
    error(picker)
  end
  return picker
end

function M.set_transparent(value)
  M.transparent = value
  state.write("transparency.state", value and "1" or "0")
  invalidate_colors()
  -- Restore the theme's real highlights before reading its solid background.
  local name = active_colorscheme or vim.g.colors_name
  if name and name ~= "" then
    vim.cmd.colorscheme(name)
  else
    vim.api.nvim_exec_autocmds("ColorScheme", {})
  end
end

return M
