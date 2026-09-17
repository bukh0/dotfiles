local state = require("utils.state")

local FALLBACK = "ayu-dark"

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local name = state.read("colorscheme.state", FALLBACK)

        if pcall(vim.cmd.colorscheme, name) then
          return
        end

        -- vim.notify during startup is swallowed before the notifier exists
        vim.schedule(function()
          vim.notify(
            ("colorscheme '%s' failed to load, falling back to %s"):format(name, FALLBACK),
            vim.log.levels.WARN,
            { title = "Theme" }
          )
        end)

        pcall(vim.cmd.colorscheme, FALLBACK)
      end,
    },
  },
}
