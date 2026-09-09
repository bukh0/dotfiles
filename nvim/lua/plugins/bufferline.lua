return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin buffer" },
    },

    opts = function(_, opts)
      local theme = require("utils.theme")

      local function to_hl_group(snake_name)
        local pascal = snake_name:gsub("(^%l)", string.upper):gsub("_(%l)", function(l)
          return l:upper()
        end)
        return "BufferLine" .. pascal
      end

      local function build_groups()
        local c = theme.colors()
        if not c then
          return nil
        end

        local bg = c.base

        return {
          fill = { fg = c.dim, bg = bg },
          background = { fg = c.dim, bg = bg },

          buffer = { fg = c.dim, bg = bg },
          buffer_visible = { fg = c.fg, bg = bg },
          buffer_selected = { fg = c.fg, bg = bg, bold = true },

          numbers = { fg = c.dim, bg = bg },
          numbers_visible = { fg = c.fg, bg = bg },
          numbers_selected = { fg = c.fg, bg = bg },

          close_button = { fg = c.dim, bg = bg },
          close_button_visible = { fg = c.dim, bg = bg },
          close_button_selected = { fg = c.red, bg = bg },

          modified = { fg = c.yellow, bg = bg },
          modified_visible = { fg = c.yellow, bg = bg },
          modified_selected = { fg = c.yellow, bg = bg },

          -- Thin separators give each tab a defined edge without a hard box —
          -- softer than a solid line, less "blocky" than none at all.
          separator = { fg = c.dim, bg = bg },
          separator_visible = { fg = c.dim, bg = bg },
          separator_selected = { fg = c.dim, bg = bg },
          offset_separator = { fg = c.dim, bg = bg },

          indicator_selected = { fg = c.accent, bg = bg },
          indicator_visible = { fg = bg, bg = bg },

          diagnostic = { fg = c.dim, bg = bg },
          diagnostic_visible = { fg = c.fg, bg = bg },
          diagnostic_selected = { fg = c.fg, bg = bg },

          error = { fg = c.red, bg = bg },
          error_visible = { fg = c.red, bg = bg },
          error_selected = { fg = c.red, bg = bg, bold = true },
          error_diagnostic = { fg = c.red, bg = bg },
          error_diagnostic_visible = { fg = c.red, bg = bg },
          error_diagnostic_selected = { fg = c.red, bg = bg },

          warning = { fg = c.yellow, bg = bg },
          warning_visible = { fg = c.yellow, bg = bg },
          warning_selected = { fg = c.yellow, bg = bg, bold = true },
          warning_diagnostic = { fg = c.yellow, bg = bg },
          warning_diagnostic_visible = { fg = c.yellow, bg = bg },
          warning_diagnostic_selected = { fg = c.yellow, bg = bg },

          info = { fg = c.blue, bg = bg },
          info_visible = { fg = c.blue, bg = bg },
          info_selected = { fg = c.blue, bg = bg, bold = true },
          info_diagnostic = { fg = c.blue, bg = bg },
          info_diagnostic_visible = { fg = c.blue, bg = bg },
          info_diagnostic_selected = { fg = c.blue, bg = bg },

          hint = { fg = c.dim, bg = bg },
          hint_visible = { fg = c.dim, bg = bg },
          hint_selected = { fg = c.dim, bg = bg, bold = true },
        }
      end

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        mode = "buffers",
        numbers = "none",

        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        middle_mouse_command = "bdelete! %d",

        indicator = {
          style = "underline",
        },

        buffer_close_icon = "󰅖",
        modified_icon = "●",
        close_icon = "",

        left_trunc_marker = "",
        right_trunc_marker = "",

        -- Slightly shorter names + a touch of breathing room between icon,
        -- text, and close button reads calmer than a cramped, uniform tab_size.
        max_name_length = 18,
        max_prefix_length = 13,
        tab_size = 18,

        diagnostics = "nvim_lsp",
        diagnostics_update_in_insert = false,

        diagnostics_indicator = function(count, level, diagnostics_dict, _)
          local icons = { error = " ", warning = " ", info = " ", hint = " " }
          local parts = {}
          for name, n in pairs(diagnostics_dict) do
            if icons[name] and n > 0 then
              table.insert(parts, icons[name] .. n)
            end
          end
          return table.concat(parts, " ")
        end,

        color_icons = true,
        show_buffer_icons = true,
        -- Only show the close (x) on hover/active, not on every idle tab —
        -- less visual noise across a full row of buffers.
        show_buffer_close_icons = true,
        show_close_icon = false,
        show_tab_indicators = false,

        -- "thin" replaces the invisible {"",""} pair with a real (but
        -- restrained) divider glyph between tabs.
        separator_style = { "", "" },
        enforce_regular_tabs = false,

        always_show_bufferline = false,

        -- Keeps tab order stable relative to where you are, instead of
        -- buffers jumping position — the closest thing to a "smooth"
        -- transition a text UI can offer, since nothing visually teleports.
        sort_by = "insert_after_current",

        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            highlight = "Directory",
            text_align = "left",
            padding = 1,
          },
        },

        hover = {
          enabled = true,
          delay = 150,
        },
      })

      opts.highlights = build_groups() or {}

      theme.on_colorscheme(function()
        local groups = build_groups()
        if not groups then
          return
        end
        for snake_name, def in pairs(groups) do
          vim.api.nvim_set_hl(0, to_hl_group(snake_name), def)
        end
      end)
    end,
  },
}
