return {
  {
    "willothy/nvim-cokeline",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      -- FORCE Neovim's native tabline highlights to be completely transparent on startup
      vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE", ctermbg = "NONE" })
      vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE", ctermbg = "NONE" })

      local cokeline = require("cokeline")
      local theme = require("utils.theme")

      local function get_color(key)
        local c = theme.colors()
        return c and c[key] or "NONE"
      end

      -- Ensure transparency persists even if your dynamic theme switches
      theme.on_colorscheme(function()
        vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE", ctermbg = "NONE" })
        vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE", ctermbg = "NONE" })
      end)

      -- buffer.devicon is nil for buffers with no icon match; guard both fields
      -- so an unmatched filetype doesn't error instead of just showing no icon.
      local function devicon(buffer)
        local d = buffer.devicon
        return d and d.icon or "", d and d.color or nil
      end

      cokeline.setup({
        -- Hides the tabline completely if you only have 1 file open
        show_if_buffers_are_at_least = 2,
        fill_hl = "TabLineFill",

        default_hl = {
          fg = function(buffer)
            return buffer.is_focused and get_color("fg") or get_color("dim")
          end,
          bg = "NONE",
        },

        -- Offset the top bar when the Snacks explorer is open.
        -- Snacks' sidebar preset wraps its input/list/preview windows (all
        -- floats) inside one real split — filetype snacks_layout_box — and
        -- that split is what cokeline can actually measure. Confirmed by
        -- inspecting the window list directly: it's the only entry with
        -- float=false, col=0 while the explorer is open.
        sidebar = {
          filetype = {
            "snacks_layout_box",
          },
          components = {
            {
              text = "  Explorer",
              fg = function() return get_color("accent") end,
              bold = true,
            },
          },
        },

        components = {
          { text = "  " },
          -- File Icon
          {
            text = function(buffer)
              local icon = devicon(buffer)
              return icon .. " "
            end,
            fg = function(buffer)
              local _, colour = devicon(buffer)
              return buffer.is_focused and (colour or get_color("accent")) or get_color("dim")
            end,
          },
          -- Filename (Accent coloured if focused)
          {
            text = function(buffer) return buffer.unique_prefix .. buffer.filename end,
            bold = function(buffer) return buffer.is_focused end,
            fg = function(buffer)
              return buffer.is_focused and get_color("accent") or get_color("dim")
            end,
          },
          -- Diagnostics
          {
            text = function(buffer)
              if buffer.diagnostics.errors > 0 then return "  " end
              if buffer.diagnostics.warnings > 0 then return " 󰀪 " end
              return ""
            end,
            fg = function(buffer)
              if buffer.diagnostics.errors > 0 then return get_color("red") end
              if buffer.diagnostics.warnings > 0 then return get_color("yellow") end
              return get_color("dim")
            end,
          },
          { text = " " },
          -- Close button / Modified indicator
          {
            text = function(buffer)
              if buffer.is_modified then return "●" end
              if buffer.is_focused then return "󰅖" end
              return " "
            end,
            fg = function(buffer)
              return buffer.is_modified and get_color("yellow") or get_color("dim")
            end,
            on_click = function(_, _, _, _, buffer)
              buffer:delete()
            end,
          },
          { text = "  " },
        },
      })
    end,
    keys = {
      { "<S-h>", "<Plug>(cokeline-focus-prev)", desc = "Prev buffer" },
      { "<S-l>", "<Plug>(cokeline-focus-next)", desc = "Next buffer" },
    },
  }
}
