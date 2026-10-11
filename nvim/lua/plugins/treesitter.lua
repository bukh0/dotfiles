return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    local want = {
      "bash", "c", "cmake", "cpp", "diff", "html", "javascript", "json", "lua", "luadoc",
      "markdown", "markdown_inline", "python", "query", "regex", "toml", "vim", "vimdoc", "yaml",
    }
    local have = ts.get_installed()
    local missing = vim.tbl_filter(function(lang)
      return not vim.list_contains(have, lang)
    end, want)
    if #missing > 0 then
      ts.install(missing)
    end
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        if pcall(vim.treesitter.start, ev.buf) then
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
