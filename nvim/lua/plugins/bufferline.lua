return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    opts = function(_, opts)
      -- Hardcode your exact hex colors here. 
      -- Pre-filled with ayu-dark defaults as a starting point.
      local c = {
        bg = "#0f1419",     -- Main background
        fg = "#e6e1cf",     -- Active text
        dim = "#5c6773",    -- Inactive text / comments
        blue = "#36a3d9",   -- Info/Indicators
        yellow = "#e6c547", -- Warnings/Modified
        red = "#ff3333",    -- Errors
      }

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        mode = "buffers",
        numbers = "none",
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        middle_mouse_command = "bdelete! %d",
        
        indicator = {
          style = "icon",
          icon = "▎",
        },

        buffer_close_icon = "󰅖",
        modified_icon = "",
        close_icon = "󰅖",
        left_trunc_marker = "",
        right_trunc_marker = "",

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
        always_show_bufferline = true,

        hover = {
          enabled = true,
          delay = 200,
          -- 'reveal = {"close"}' is removed so the 'x' button is always visible
        },
        sort_by = "id",
      })

      -- Function to slam our hardcoded colors directly into Neovim
      local function apply_hardcoded_highlights()
        local groups = {
          Fill = { fg = c.dim, bg = c.bg },
          Background = { fg = c.dim, bg = c.bg },
          
          Tab = { fg = c.dim, bg = c.bg, italic = false, bold = false },
          TabSelected = { fg = c.fg, bg = c.bg, italic = false, bold = false },
          
          BufferVisible = { fg = c.fg, bg = c.bg, italic = false, bold = false },
          BufferSelected = { fg = c.fg, bg = c.bg, italic = false, bold = true },
          
          Numbers = { fg = c.dim, bg = c.bg, italic = false },
          NumbersVisible = { fg = c.fg, bg = c.bg, italic = false },
          NumbersSelected = { fg = c.fg, bg = c.bg, italic = false },
          
          CloseButton = { fg = c.dim, bg = c.bg },
          CloseButtonVisible = { fg = c.fg, bg = c.bg },
          CloseButtonSelected = { fg = c.fg, bg = c.bg },
          
          Modified = { fg = c.yellow, bg = c.bg },
          ModifiedVisible = { fg = c.yellow, bg = c.bg },
          ModifiedSelected = { fg = c.yellow, bg = c.bg },
          
          Diagnostic = { fg = c.dim, bg = c.bg, italic = false },
          DiagnosticVisible = { fg = c.fg, bg = c.bg, italic = false },
          DiagnosticSelected = { fg = c.fg, bg = c.bg, italic = false },
          
          Error = { fg = c.red, bg = c.bg, italic = false },
          ErrorVisible = { fg = c.red, bg = c.bg, italic = false },
          ErrorSelected = { fg = c.red, bg = c.bg, italic = false, bold = true },
          
          Warning = { fg = c.yellow, bg = c.bg, italic = false },
          WarningVisible = { fg = c.yellow, bg = c.bg, italic = false },
          WarningSelected = { fg = c.yellow, bg = c.bg, italic = false, bold = true },
          
          Info = { fg = c.blue, bg = c.bg, italic = false },
          InfoVisible = { fg = c.blue, bg = c.bg, italic = false },
          InfoSelected = { fg = c.blue, bg = c.bg, italic = false, bold = true },
          
          Hint = { fg = c.dim, bg = c.bg, italic = false },
          HintVisible = { fg = c.dim, bg = c.bg, italic = false },
          HintSelected = { fg = c.dim, bg = c.bg, italic = false, bold = true },
        }

        for group, def in pairs(groups) do
          vim.api.nvim_set_hl(0, "BufferLine" .. group, def)
        end
      end

      -- Nullify bufferline's internal highlighting to stop it from interfering
      opts.highlights = {}

      -- Neovim clears all highlights whenever a new theme loads.
      -- Re-apply our hardcoded colors automatically if that happens.
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = apply_hardcoded_highlights,
      })
      
      -- Apply immediately on startup
      vim.schedule(apply_hardcoded_highlights)
    end,
  },
}
