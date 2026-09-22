-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Format and save (uses LazyVim's format controller so <leader>uf toggle is respected)
vim.api.nvim_create_user_command("Ws", function()
  LazyVim.format({ force = true })
  vim.cmd("write")
end, { desc = "Format and save" })

-- Only expand at the very start of a : command, not inside search or :! shell commands
vim.cmd([[cabbrev <expr> ws (getcmdtype()==':' && getcmdpos()<=3) ? 'Ws' : 'ws']])
