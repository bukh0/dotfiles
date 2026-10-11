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

local function noice_has(kind)
  return package.loaded["noice"] and require("noice").api.status[kind].has()
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
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          {
            function() return require("noice").api.status.command.get() end,
            cond = function() return noice_has("command") end,
          },
          {
            function() return require("noice").api.status.mode.get() end,
            cond = function() return noice_has("mode") end,
          },
          {
            function() return require("lazy.status").updates() end,
            cond = function() return require("lazy.status").has_updates() end,
          },
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
