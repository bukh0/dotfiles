return {
  {
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local state_file = vim.fn.stdpath("state") .. "/colorscheme.state"
        local name = "ayu-dark"
        local f = io.open(state_file, "r")
        if f then
          local content = f:read("*a")
          f:close()
          if content and content ~= "" then
            name = content
          end
        end
        vim.cmd.colorscheme(name)
      end,
    },
  },
}
