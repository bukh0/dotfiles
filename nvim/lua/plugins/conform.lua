return {
  "stevearc/conform.nvim",
  lazy = true,
  cmd = "ConformInfo",
  init = function()
    vim.api.nvim_create_user_command("Ws", function(ev)
      require("conform").format({ lsp_format = "fallback", timeout_ms = 1000 })
      vim.cmd({ cmd = "write", bang = ev.bang })
    end, { bang = true, desc = "Format and save" })
    vim.cmd([[cabbrev <expr> ws (getcmdtype()==':' && getcmdpos()<=3) ? 'Ws' : 'ws']])
  end,
  opts = {
    formatters_by_ft = { lua = { "stylua" } },
    default_format_opts = { lsp_format = "fallback" },
  },
  keys = {
    { "<leader>cf", function() require("conform").format() end, mode = { "n", "x" }, desc = "Format" },
  },
}
