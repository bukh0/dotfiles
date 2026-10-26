local function is_prose()
  return vim.bo.filetype == "text" or vim.bo.filetype == "markdown"
end

local function get_word_char_count()
  local stats = vim.fn.wordcount()
  if stats.visual_words then
    return stats.visual_words .. "W / " .. stats.visual_chars .. "C (Vis)"
  end
  return stats.words .. "W / " .. stats.chars .. "C"
end

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = function()
    return {
      options = {
        theme = "auto",
        globalstatus = true,
        disabled_filetypes = { statusline = { "dashboard", "alpha", "starter", "snacks_dashboard" } },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          "diagnostics",
          "encoding",
          "fileformat",
          "filetype",
        },
        lualine_y = { "progress", { get_word_char_count, cond = is_prose } },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_c = { "filename" },
        lualine_x = { "location" },
      },
    }
  end,
}
