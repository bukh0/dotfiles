local state = require("utils.state")

local FALLBACK = "ayu-dark"

local theme_plugins = {
  ["ayu"] = "neovim-ayu",
  ["ayu-dark"] = "neovim-ayu",
  ["kanagawa"] = "kanagawa.nvim",
  ["kanagawa-wave"] = "kanagawa.nvim",
  ["kanagawa-dragon"] = "kanagawa.nvim",
  ["kanagawa-lotus"] = "kanagawa.nvim",
  ["gruvbox"] = "gruvbox.nvim",
  ["nightfox"] = "nightfox.nvim",
  ["dayfox"] = "nightfox.nvim",
  ["dawnfox"] = "nightfox.nvim",
  ["duskfox"] = "nightfox.nvim",
  ["nordfox"] = "nightfox.nvim",
  ["terafox"] = "nightfox.nvim",
  ["carbonfox"] = "nightfox.nvim",
  ["rose-pine"] = "rose-pine",
  ["rose-pine-moon"] = "rose-pine",
  ["rose-pine-dawn"] = "rose-pine",
  ["everforest"] = "everforest",
  ["gruvbox-material"] = "gruvbox-material",
  ["sonokai"] = "sonokai",
  ["edge"] = "edge",
  ["onedark"] = "onedark.nvim",
  ["dracula"] = "dracula.nvim",
  ["material"] = "material.nvim",
  ["github_dark"] = "github-nvim-theme",
  ["github_dark_default"] = "github-nvim-theme",
  ["nord"] = "nord.nvim",
  ["nordic"] = "nordic.nvim",
  ["monokai-pro"] = "monokai-pro.nvim",
  ["solarized"] = "solarized.nvim",
  ["vscode"] = "vscode.nvim",
  ["modus"] = "modus-themes.nvim",
  ["melange"] = "melange-nvim",
  ["onenord"] = "onenord.nvim",
  ["bamboo"] = "bamboo.nvim",
  ["vague"] = "vague.nvim",
  ["kanso"] = "kanso.nvim",
  ["poimandres"] = "poimandres.nvim",
  ["arctic"] = "arctic.nvim",
}

local function load_theme_plugin(name)
  local plugin = theme_plugins[name]
  if not plugin then
    return
  end

  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load({ plugins = { plugin } })
  end
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local name = state.read("colorscheme.state", FALLBACK)

        load_theme_plugin(name)
        if pcall(vim.cmd.colorscheme, name) then
          return
        end

        -- vim.notify during startup is swallowed before the notifier exists
        vim.schedule(function()
          vim.notify(
            ("colorscheme '%s' failed to load, falling back to %s"):format(name, FALLBACK),
            vim.log.levels.WARN,
            { title = "Theme" }
          )
        end)

        load_theme_plugin(FALLBACK)
        pcall(vim.cmd.colorscheme, FALLBACK)
      end,
    },
  },
}
