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
    local function attach(buf)
      if not vim.api.nvim_buf_is_loaded(buf) then return end
      if pcall(vim.treesitter.start, buf) then
        local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
        if lang and lang ~= "c" and lang ~= "cpp" and vim.treesitter.query.get(lang, "indents") then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end
    end
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
      callback = function(ev)
        attach(ev.buf)
      end,
    })
    if #missing > 0 then
      ts.install(missing):await(vim.schedule_wrap(function()
        -- FileType may have fired before its parser was available. Retry even
        -- after partial installation failure so successful parsers take effect.
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) then
            local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
            if vim.list_contains(missing, lang) then attach(buf) end
          end
        end
      end))
    end
  end,
}
