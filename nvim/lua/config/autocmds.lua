-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Format (clangd) and save
vim.api.nvim_create_user_command("Ws", function()
  require("conform").format({ lsp_fallback = true })
  vim.cmd("write")
end, { desc = "Format (clangd) and save" })

vim.cmd("cnoreabbrev ws Ws")

-- Apply transparent UI highlights and keep them updated on theme changes
require("utils.theme").on_colorscheme(function()
  -- Add any extra custom post-theme logic here if needed
end)
