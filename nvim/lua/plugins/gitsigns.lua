return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "" },
      changedelete = { text = "▎" },
    },
    on_attach = function(buf)
      local gs = require("gitsigns")
      local function map(lhs, rhs, desc, mode)
        vim.keymap.set(mode or "n", lhs, rhs, { buffer = buf, desc = desc })
      end
      map("]h", function() gs.nav_hunk("next") end, "Next hunk")
      map("[h", function() gs.nav_hunk("prev") end, "Prev hunk")
      map("<leader>ghs", gs.stage_hunk, "Stage hunk")
      map("<leader>ghr", gs.reset_hunk, "Reset hunk")
      map("<leader>ghp", gs.preview_hunk_inline, "Preview hunk")
      map("<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
      map("<leader>ghd", gs.diffthis, "Diff this")
    end,
  },
}
