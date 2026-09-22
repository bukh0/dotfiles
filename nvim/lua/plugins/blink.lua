return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      preset = "none", -- disable the preset entirely, define everything yourself

      ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },

      ["<CR>"] = { "accept", "fallback" },
      ["<C-y>"] = { "accept", "fallback" },
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-e>"] = { "hide" },
    },
  },
}
