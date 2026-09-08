return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function(_, opts)
      local theme = require("utils.theme")

      local function build_highlights()
        local c = theme.colors()
        return {
          fill = { bg = "NONE" },
          background = { bg = "NONE", fg = c.dim },
          tab = { bg = "NONE" },
          tab_selected = { bg = "NONE" },
          buffer_visible = { bg = "NONE", fg = c.fg },
          buffer_selected = { bold = true, bg = "NONE", fg = c.accent },
          close_button = { bg = "NONE" },
          close_button_visible = { bg = "NONE" },
          close_button_selected = { bg = "NONE", fg = c.accent },
          modified = { bg = "NONE", fg = c.yellow },
          modified_visible = { bg = "NONE", fg = c.yellow },
          modified_selected = { bg = "NONE", fg = c.yellow },
          indicator_selected = { fg = c.accent, bg = "NONE" },
          separator = { fg = "NONE", bg = "NONE" },
          separator_visible = { fg = "NONE", bg = "NONE" },
          separator_selected = { fg = "NONE", bg = "NONE" },
        }
      end

      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        mode = "buffers",
        numbers = "none",
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        indicator = { style = "underline" },
        buffer_close_icon = "󰅖",
        modified_icon = "●",
        left_trunc_marker = "",
        right_trunc_marker = "",
        max_name_length = 21,
        tab_size = 21,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count)
          return " " .. count
        end,
        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = false,
        separator_style = "none",
        always_show_bufferline = true,
        offsets = {
          { filetype = "neo-tree", text = "File Explorer", text_align = "center", separator = true },
        },
        sort_by = "insert_after_current",
      })

      opts.highlights = build_highlights()

      theme.on_colorscheme(function()
        local ok, bufferline = pcall(require, "bufferline")
        if ok then
          bufferline.setup(vim.tbl_deep_extend("force", opts, { highlights = build_highlights() }))
        end
      end)
    end,
  },
}
