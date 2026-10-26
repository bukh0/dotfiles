return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    cmd = "Obsidian",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      legacy_commands = false,
      workspaces = {
        { name = "main", path = "~/notes/main" },
      },
      daily_notes = { folder = "daily" },
      picker = {
        name = "snacks.picker",
        note_mappings = {
          new = "<C-x>",
          insert_link = "<C-l>",
        },
      },
      ui = { enable = false },
      frontmatter = { enabled = false },
      note_id_func = function(title)
        if title ~= nil and title ~= "" then
          local slug = title:lower():gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
          if slug ~= "" then return slug end
        end
        return tostring(os.time())
      end,
    },
    keys = {
      { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
      { "<leader>of", "<cmd>Obsidian quick_switch<cr>", desc = "Find note" },
      { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Grep notes" },
      { "<leader>od", "<cmd>Obsidian today<cr>", desc = "Daily note" },
      { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
}
