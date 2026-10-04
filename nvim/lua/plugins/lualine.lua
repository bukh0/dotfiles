-- ~/.config/nvim/lua/plugins/lualine.lua

-- Helper function for wordcount
local function is_prose()
  return vim.bo.filetype == "text" or vim.bo.filetype == "markdown"
end

-- 2. Define a function to process and structure the word/character count
local function get_word_char_count()
  local stats = vim.fn.wordcount()
  if stats.visual_words then
    return stats.visual_words .. "W / " .. stats.visual_chars .. "C (Vis)"
  else
    return stats.words .. "W / " .. stats.bytes .. "C"
  end
end


return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        theme = "auto",
        globalstatus = true,
        disabled_filetypes = {
          statusline = { "dashboard", "alpha", "starter" },
        },
        -- no component_separators / section_separators here — inherit lualine's
        -- own defaults, which you've confirmed already render as sharp triangles
      })

      -- Explicitly tell Lualine to stay out of the top tab bar so Cokeline can take over
      opts.tabline = {}

      opts.sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { "filename" },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress", { get_word_char_count, cond = is_prose }},
        lualine_z = { "location" },
      }

      opts.inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      }
    end,
  },
}
