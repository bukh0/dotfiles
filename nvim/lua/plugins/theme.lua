local state = require("utils.state")

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local name = state.read("colorscheme.state", "ayu-dark")
        local ok, err = pcall(vim.cmd.colorscheme, name)
        if not ok then
          vim.notify("colorscheme '" .. name .. "' failed to load: " .. tostring(err), vim.log.levels.WARN)
          pcall(vim.cmd.colorscheme, "ayu-dark")
        end
      end,
    },
  },
}
