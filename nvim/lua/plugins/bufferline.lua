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

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        mode = "buffers",

        numbers = "none",

        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        middle_mouse_command = "bdelete! %d",

        indicator = {
          style = "none",
        },

        buffer_close_icon = "󰅖",
        modified_icon = "●",
        close_icon = "󰅖",

        left_trunc_marker = "",
        right_trunc_marker = "",

        max_name_length = 21,
        max_prefix_length = 15,
        tab_size = 21,

        diagnostics = "nvim_lsp",
        diagnostics_update_in_insert = false,

        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = false,
        show_tab_indicators = false,

        separator_style = { "", "" },
        enforce_regular_tabs = false,

        always_show_bufferline = false,

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
          delay = 200,
        },
      })

      local function apply_bufferline_highlights()
        local c = theme.colors()

        if not c then
          return
        end

        local groups = {
          -- Main bufferline
          Fill = {
            fg = c.dim,
            bg = c.bg,
          },

          Background = {
            fg = c.dim,
            bg = c.bg,
          },

          Buffer = {
            fg = c.dim,
            bg = c.bg,
          },

          BufferVisible = {
            fg = c.fg,
            bg = c.bg,
          },

          BufferSelected = {
            fg = c.fg,
            bg = c.bg,
            bold = true,
          },

          -- Numbers
          Numbers = {
            fg = c.dim,
            bg = c.bg,
          },

          NumbersVisible = {
            fg = c.fg,
            bg = c.bg,
          },

          NumbersSelected = {
            fg = c.fg,
            bg = c.bg,
          },

          -- Close buttons
          CloseButton = {
            fg = c.dim,
            bg = c.bg,
          },

          CloseButtonVisible = {
            fg = c.fg,
            bg = c.bg,
          },

          CloseButtonSelected = {
            fg = c.fg,
            bg = c.bg,
          },

          -- Modified
          Modified = {
            fg = c.yellow,
            bg = c.bg,
          },

          ModifiedVisible = {
            fg = c.yellow,
            bg = c.bg,
          },

          ModifiedSelected = {
            fg = c.yellow,
            bg = c.bg,
          },

          -- Separators
          Separator = {
            fg = c.bg,
            bg = c.bg,
          },

          SeparatorVisible = {
            fg = c.bg,
            bg = c.bg,
          },

          SeparatorSelected = {
            fg = c.bg,
            bg = c.bg,
          },

          OffsetSeparator = {
            fg = c.bg,
            bg = c.bg,
          },

          -- Indicator
          IndicatorSelected = {
            fg = c.bg,
            bg = c.bg,
          },

          IndicatorVisible = {
            fg = c.bg,
            bg = c.bg,
          },

          -- Diagnostics
          Diagnostic = {
            fg = c.dim,
            bg = c.bg,
          },

          DiagnosticVisible = {
            fg = c.fg,
            bg = c.bg,
          },

          DiagnosticSelected = {
            fg = c.fg,
            bg = c.bg,
          },

          -- Errors
          Error = {
            fg = c.red,
            bg = c.bg,
          },

          ErrorVisible = {
            fg = c.red,
            bg = c.bg,
          },

          ErrorSelected = {
            fg = c.red,
            bg = c.bg,
            bold = true,
          },

          -- Warnings
          Warning = {
            fg = c.yellow,
            bg = c.bg,
          },

          WarningVisible = {
            fg = c.yellow,
            bg = c.bg,
          },

          WarningSelected = {
            fg = c.yellow,
            bg = c.bg,
            bold = true,
          },

          -- Info
          Info = {
            fg = c.blue,
            bg = c.bg,
          },

          InfoVisible = {
            fg = c.blue,
            bg = c.bg,
          },

          InfoSelected = {
            fg = c.blue,
            bg = c.bg,
            bold = true,
          },

          -- Hints
          Hint = {
            fg = c.dim,
            bg = c.bg,
          },

          HintVisible = {
            fg = c.dim,
            bg = c.bg,
          },

          HintSelected = {
            fg = c.dim,
            bg = c.bg,
            bold = true,
          },
        }

        for group, definition in pairs(groups) do
          vim.api.nvim_set_hl(
            0,
            "BufferLine" .. group,
            definition
          )
        end
      end

      opts.highlights = {}

      theme.on_colorscheme(apply_bufferline_highlights)

      vim.schedule(function()
        apply_bufferline_highlights()
      end)
    end,
  },
}
