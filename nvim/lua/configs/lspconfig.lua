require("nvchad.configs.lspconfig").defaults()

local nvlsp = require "nvchad.configs.lspconfig"
local servers = { "html", "cssls","clangd","qmlls" }

-- Loop through the servers and set them up using the native 0.11 API
for _, lsp in ipairs(servers) do
  
  -- 1. Define the configuration for the server
  vim.lsp.config(lsp, {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  })
  
  -- 2. Enable the server
  vim.lsp.enable(lsp)
end
