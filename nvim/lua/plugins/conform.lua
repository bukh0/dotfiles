return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  opts = {
    formatters_by_ft = { lua = { "stylua" } },
    default_format_opts = { lsp_format = "fallback" },
  },
  keys = {
    { "<leader>cf", function() require("conform").format() end, mode = { "n", "x" }, desc = "Format" },
  },
}
