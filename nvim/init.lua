-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Load transparency toggle script
require("config.transparency").setup()

-- Persist whichever colorscheme is active, so LazyVim's opts.colorscheme
-- function in lua/plugins/theme.lua can restore it on next startup
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function(args)
    local f = io.open(vim.fn.stdpath("state") .. "/colorscheme.state", "w")
    if f then
      f:write(args.match)
      f:close()
    end
  end,
})
