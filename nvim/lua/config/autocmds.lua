local augroup = vim.api.nvim_create_augroup("user_autocmds", { clear = true })
local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", { group = augroup, callback = function() vim.hl.on_yank() end })
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup,
  callback = function()
    if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end
  end,
})
autocmd("VimResized", {
  group = augroup,
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})
autocmd("BufReadPost", {
  group = augroup,
  callback = function(ev)
    if vim.bo[ev.buf].filetype:match("^git") then return end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
autocmd("FileType", {
  group = augroup,
  pattern = { "help", "qf", "man", "checkhealth", "notify", "lspinfo" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})
autocmd("BufWritePre", {
  group = augroup,
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then return end
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
  end,
})

vim.api.nvim_create_user_command("Ws", function()
  require("conform").format({ lsp_format = "fallback" })
  vim.cmd("write")
end, { desc = "Format and save" })

vim.cmd([[cabbrev <expr> ws (getcmdtype()==':' && getcmdpos()<=3) ? 'Ws' : 'ws']])
