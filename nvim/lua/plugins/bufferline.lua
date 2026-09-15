-- ~/.config/nvim/lua/plugins/bufferline.lua
local theme = require("utils.theme")

-- 1. Extract helper functions outside of the plugin spec
local function to_hl_group(snake_name)
  -- Simplifies snake_case to PascalCase (e.g., buffer_selected -> BufferSelected)
  local pascal = snake_name:gsub("_%l", string.upper):gsub("_", ""):gsub("^%l", string.upper)
  return "BufferLine" .. pascal
end

local function build_groups()
  local c = theme.colors()
  if not c then return nil end

  local bg = c.base

  return {
    fill = { fg = c.dim, bg = bg },
    background = { fg = c.dim, bg = bg },

    buffer = { fg = c.dim, bg = bg },
    buffer_visible = { fg = c.dim, bg = bg },
    buffer_selected = { fg = c.fg, bg = bg, bold = true },

    numbers = { fg = c.dim, bg = bg },
    numbers_visible = { fg = c.dim, bg = bg },
    numbers_selected = { fg = c.fg, bg = bg, bold = true },

    close_button = { fg = c.dim, bg = bg },
    close_button_visible = { fg = c.dim, bg = bg },
    close_button_selected = { fg = c.red, bg = bg },

    modified = { fg = c.dim, bg = bg },
    modified_visible = { fg = c.dim, bg = bg },
    modified_selected = { fg = c.accent, bg = bg, bold = true },

    separator = { fg = bg, bg = bg },
    separator_visible = { fg = bg, bg = bg },
    separator_selected = { fg = bg, bg = bg },
    offset_separator = { fg = c.dim, bg = bg },

    indicator_selected = { fg = c.accent, bg = bg },
    indicator_visible = { fg = bg, bg = bg },

    diagnostic = { fg = c.dim, bg = bg },
    diagnostic_visible = { fg = c.dim, bg = bg },
    diagnostic_selected = { fg = c.fg, bg = bg },

    -- Filename text (mirrors standard buffer colours)
    error = { fg = c.dim, bg = bg },
    error_visible = { fg = c.dim, bg = bg },
    error_selected = { fg = c.fg, bg = bg, bold = true },
    -- Diagnostic indicator/icon (keeps the red colour)
    error_diagnostic = { fg = c.red, bg = bg, bold = true },
    error_diagnostic_visible = { fg = c.red, bg = bg, bold = true },
    error_diagnostic_selected = { fg = c.red, bg = bg, bold = true },

    -- Filename text
    warning = { fg = c.dim, bg = bg },
    warning_visible = { fg = c.dim, bg = bg },
    warning_selected = { fg = c.fg, bg = bg, bold = true },
    -- Diagnostic indicator/icon
    warning_diagnostic = { fg = c.yellow, bg = bg, bold = true },
    warning_diagnostic_visible = { fg = c.yellow, bg = bg, bold = true },
    warning_diagnostic_selected = { fg = c.yellow, bg = bg, bold = true },

    -- Filename text
    info = { fg = c.dim, bg = bg },
    info_visible = { fg = c.dim, bg = bg },
    info_selected = { fg = c.fg, bg = bg, bold = true },
    -- Diagnostic indicator/icon
    info_diagnostic = { fg = c.blue, bg = bg },
    info_diagnostic_visible = { fg = c.blue, bg = bg },
    info_diagnostic_selected = { fg = c.blue, bg = bg },

    -- Filename text
    hint = { fg = c.dim, bg = bg },
    hint_visible = { fg = c.dim, bg = bg },
    hint_selected = { fg = c.fg, bg = bg, bold = true },
    -- Diagnostic indicator/icon
    hint_diagnostic = { fg = c.dim, bg = bg },
    hint_diagnostic_visible = { fg = c.dim, bg = bg },
    hint_diagnostic_selected = { fg = c.dim, bg = bg, bold = true },
  }
end

-- 2. Build keys table dynamically before returning the spec
local bufferline_keys = {
  { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
  { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
  { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin buffer" },
  { "<leader>bc", "<cmd>BufferLinePickClose<cr>", desc = "Pick buffer to close" },
  { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close other buffers" },
}

for i = 1, 9 do
  table.insert(bufferline_keys, {
    "<leader>" .. i,
    function() require("bufferline").go_to(i, true) end,
    desc = "Buffer " .. i,
  })
end

return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = bufferline_keys,
    opts = function(_, opts)
      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        mode = "buffers",
        numbers = "ordinal",

        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        middle_mouse_command = "bdelete! %d",

        indicator = { style = "none" },

        buffer_close_icon = "󰅖",
        modified_icon = "●",
        close_icon = "",

        left_trunc_marker = "",
        right_trunc_marker = "",

        max_name_length = 18,
        max_prefix_length = 13,
        tab_size = 20,

        diagnostics = "nvim_lsp",
        diagnostics_update_in_insert = false,

        diagnostics_indicator = function(count, level, diagnostics_dict, _)
          local icons = { error = "", warning = "󰀪", info = "", hint = "󰌵" }
          local order = { "error", "warning", "info", "hint" }
          local parts = {}
          
          for _, name in ipairs(order) do
            local n = diagnostics_dict[name]
            if n and n > 0 then
              table.insert(parts, icons[name])
            end
          end
          
          if #parts == 0 then
            return ""
          end
          
          return " " .. table.concat(parts, " ")
        end,

        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = false,
        show_tab_indicators = false,

        separator_style = "thin",
        enforce_regular_tabs = false,
        always_show_bufferline = false,
        sort_by = "insert_after_current",

        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            highlight = "Directory",
            text_align = "left",
            padding = 1,
            separator = true,
          },
        },

        hover = {
          enabled = true,
          delay = 150,
          reveal = { "close" },
        },
      })

      opts.highlights = build_groups() or {}

      theme.on_colorscheme(function()
        local groups = build_groups()
        if not groups then return end
        
        for snake_name, def in pairs(groups) do
          vim.api.nvim_set_hl(0, to_hl_group(snake_name), def)
        end
      end)
    end,
  },
}
