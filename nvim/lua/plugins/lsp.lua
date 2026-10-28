local function switch_source_header(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })[1]
  if not client then return end
  local win = vim.api.nvim_get_current_win()
  client:request("textDocument/switchSourceHeader", vim.lsp.util.make_text_document_params(bufnr), function(err, result)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= bufnr then return end
    if err or not result or result == "" then
      vim.notify("No source/header found", vim.log.levels.INFO)
      return
    end
    vim.api.nvim_win_call(win, function()
      vim.cmd.edit(vim.fn.fnameescape(vim.uri_to_fname(result)))
    end)
  end, bufnr)
end

return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts = { ensure_installed = { "stylua" } },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 3,
          prefix = "",
          source = "if_many",
          severity = { min = vim.diagnostic.severity.WARN },
          format = function(diagnostic)
            return vim.trim(diagnostic.message:gsub("%s+", " "))
          end,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅙",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "󰋼",
            [vim.diagnostic.severity.HINT] = "󰌵",
          },
        },
        float = { border = "rounded", source = true },
      })

      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders",
          "--fallback-style=llvm",
        },
        init_options = { usePlaceholders = true, completeUnimported = true, clangdFileStatus = true },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            completion = { callSnippet = "Replace" },
            hint = { enable = true },
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = { "clangd", "lua_ls" },
        automatic_enable = true,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local function map(lhs, rhs, desc, mode)
            vim.keymap.set(mode or "n", lhs, rhs, { buffer = ev.buf, desc = desc })
          end
          map("gd", function() Snacks.picker.lsp_definitions() end, "Goto definition")
          map("gr", function() Snacks.picker.lsp_references() end, "References")
          map("gD", vim.lsp.buf.declaration, "Goto declaration")
          map("gI", function() Snacks.picker.lsp_implementations() end, "Goto implementation")
          map("gy", function() Snacks.picker.lsp_type_definitions() end, "Goto type definition")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "x" })
          map("<leader>cr", vim.lsp.buf.rename, "Rename")
          map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.name == "clangd" then
            map("<leader>ch", function() switch_source_header(ev.buf) end, "Switch source/header")
          end
          if client and client:supports_method("textDocument/inlayHint") then
            map("<leader>uh", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
            end, "Toggle inlay hints")
          end
        end,
      })
    end,
  },
}
