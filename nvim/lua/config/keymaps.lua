-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

-- Bufferline is disabled (see lua/plugins/bufferline.lua) in favor of
-- nvim-cokeline. LazyVim's default keymaps still bind a couple of buffer
-- keys to bufferline-only commands (toggle pin, close non-pinned); those
-- commands don't exist once bufferline never loads, so pressing them throws
-- an "Unknown command" error instead of doing nothing quietly. Strip them —
-- pcall-guarded since LazyVim could rename/remove them in a future update.
for _, lhs in ipairs({ "<leader>bp", "<leader>bP" }) do
  pcall(vim.keymap.del, "n", lhs)
end
