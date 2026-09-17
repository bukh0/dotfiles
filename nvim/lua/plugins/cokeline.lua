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

      -- Components run on every redraw, for every buffer. Rebuilding the
      -- palette (nvim_get_hl calls) inside get_color() on each of those
      -- calls is wasted work — cache it, refresh only on ColorScheme.
      local palette = theme.colors() or {}
      local function get_color(key)
        return palette[key] or "NONE"
      end

      local function refresh_transparency()
        vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE", ctermbg = "NONE" })
        vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE", ctermbg = "NONE" })
        palette = theme.colors() or {}
      end

      -- Ensure transparency + palette persist across colorscheme switches
      theme.on_colorscheme(refresh_transparency)

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

        buffers = {
          -- keep terminals/quickfix/help off the bar
          filter_valid = function(buffer)
            return vim.bo[buffer.number].buftype == ""
          end,
        },

        default_hl = {
          fg = function(buffer)
            return buffer.is_focused and get_color("fg") or get_color("dim")
          end,
          bg = "NONE",
        },

        -- Offset the top bar when the Snacks explorer is open.
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
          -- `or 0` guards against errors/warnings being nil before the LSP
          -- client for that buffer has attached — without it this throws
          -- "attempt to compare number with nil" on early redraws.
          {
            text = function(buffer)
              local errors = buffer.diagnostics.errors or 0
              local warnings = buffer.diagnostics.warnings or 0
              if errors > 0 then
                return " 󰅚 " .. errors
              end
              if warnings > 0 then
                return " 󰀪 " .. warnings
              end
              return ""
            end,
            fg = function(buffer)
              local errors = buffer.diagnostics.errors or 0
              local warnings = buffer.diagnostics.warnings or 0
              if errors > 0 then return get_color("red") end
              if warnings > 0 then return get_color("yellow") end
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

      -- Bufferline's default LazyVim keymaps die with it disabled.
      -- <leader>bo (close other buffers) recreated here for cokeline.
      vim.keymap.set("n", "<leader>bo", function()
        local current = vim.api.nvim_get_current_buf()
        for _, buf in ipairs(require("cokeline.buffers").get_visible()) do
          if buf.number ~= current then
            buf:delete()
          end
        end
      end, { desc = "Delete other buffers" })

      -- vim.diagnostic events don't trigger a tabline redraw on their own —
      -- force one so error/warning counts update the instant the LSP reports
      -- them, rather than waiting for the next unrelated redraw.
      vim.api.nvim_create_autocmd("DiagnosticChanged", {
        callback = function()
          vim.schedule(function()
            vim.cmd("redrawtabline")
          end)
        end,
      })
    end,
    keys = {
      { "<S-h>", "<Plug>(cokeline-focus-prev)", desc = "Prev buffer" },
      { "<S-l>", "<Plug>(cokeline-focus-next)", desc = "Next buffer" },
    },
  }
}
