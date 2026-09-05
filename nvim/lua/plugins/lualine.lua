return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local icons = {
        sep_left = "\u{e0b6}", --  rounded left (mode block only)
        sep_right = "\u{e0b4}", --  rounded right (mode block only)
        chevron = "\u{e0b1} ", -- ‹ thin flat divider between right-side pills
        folder = "\u{f07c} ", --  open folder
        git = "\u{f126} ", --  git branch
        error = "\u{ea87} ", --  error
        warn = "\u{ea6c} ", --  warning
        info = "\u{ea74} ", --  info
        hint = "\u{f0eb} ", --  hint
        clock = "\u{f017} ", --  clock
        lsp = "\u{f085} ", --  gear / active LSP
      }

      opts.options.component_separators = ""
      opts.options.section_separators = ""
      opts.options.globalstatus = true

      -- Mode block: flat on the screen edge, rounded arrow flowing into the breadcrumb.
      opts.sections.lualine_a = {
        {
          "mode",
          separator = { left = "", right = icons.sep_right },
          padding = { left = 1, right = 1 },
        },
      }

      opts.sections.lualine_b = {}

      -- Breadcrumb-style path: folder icon + cwd, chevron, git icon + truncated path.
      opts.sections.lualine_c = {
        {
          function()
            local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
            return icons.folder .. cwd
          end,
          color = { fg = "#7aa2f7", gui = "bold" },
        },
        {
          function()
            return icons.chevron
          end,
          color = { fg = "#565f89" },
          padding = 0,
        },
        {
          "filename",
          path = 1,
          shorting_target = 40,
          icon = icons.git,
          symbols = { modified = "  ", readonly = "  ", unnamed = "" },
          color = { fg = "#a9b1d6" },
        },
      }

      -- Diagnostics: color-coded per severity, only shown when present.
      opts.sections.lualine_x = {
        {
          "diagnostics",
          sources = { "nvim_diagnostic" },
          sections = { "error", "warn", "info", "hint" },
          symbols = {
            error = icons.error,
            warn = icons.warn,
            info = icons.info,
            hint = icons.hint,
          },
          diagnostics_color = {
            error = { fg = "#f7768e" },
            warn = { fg = "#e0af68" },
            info = { fg = "#7dcfff" },
            hint = { fg = "#1abc9c" },
          },
          colored = true,
          update_in_insert = false,
          always_visible = false,
        },
        {
          -- active LSP client(s) attached to the buffer, e.g. clangd, lua_ls
          function()
            local clients = vim.lsp.get_clients({ bufnr = 0 })
            if #clients == 0 then
              return ""
            end
            local names = {}
            for _, c in ipairs(clients) do
              table.insert(names, c.name)
            end
            return icons.lsp .. table.concat(names, ", ")
          end,
          color = { fg = "#9ece6a" },
          separator = { left = icons.chevron, right = "" },
          padding = { left = 1, right = 1 },
        },
      }

      -- Right-hand info pills, connected by thin flat chevrons.
      opts.sections.lualine_y = {
        {
          "filetype",
          icon_only = false,
          separator = { left = icons.chevron, right = "" },
          padding = { left = 1, right = 1 },
        },
        {
          function()
            return "%p%%"
          end,
          separator = { left = icons.chevron, right = "" },
          padding = { left = 1, right = 1 },
        },
        {
          "location",
          separator = { left = icons.chevron, right = "" },
          padding = { left = 1, right = 1 },
        },
      }

      -- Clock: only piece with a rounded edge on the far right, matching the mode block.
      opts.sections.lualine_z = {
        {
          function()
            return icons.clock .. os.date("%R")
          end,
          separator = { left = icons.sep_left, right = "" },
          padding = { left = 1, right = 1 },
        },
      }
    end,
  },
}
