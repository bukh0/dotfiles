return {
  -- 1. Install the Ayu theme
  { 
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
  },
  -- 2. Tell LazyVim to use the dark variant
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "ayu-dark",
    },
  },
}
