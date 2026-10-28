# Neovim Config

Standalone Neovim configuration powered by `lazy.nvim` (not LazyVim).

## Setup

The installed Tree-sitter revision requires Neovim 0.12+, `tree-sitter-cli`
0.26.1+, a C compiler, `curl`, and `tar`. Install the CLI through your system
package manager, not npm. Git is needed to bootstrap and install plugins;
`ripgrep` powers text searches, and `lazygit` is needed for `<leader>gg`.
A Nerd Font provides the UI icons. Clipboard integration requires a clipboard
provider supported by Neovim (`:checkhealth vim.provider`).

On first use, Mason installs `clangd`, `lua-language-server`, and `stylua`,
and Tree-sitter installs the configured parsers. These downloads require
network access. Plugin revisions are recorded in `lazy-lock.json`.

The Obsidian vault defaults to `~/notes/main`; change `workspaces` in
`lua/plugins/notes.lua` to use a different vault.

## Configuration structure

Add plugin specs as Lua files returning a table in `lua/plugins/`; Lazy imports
that directory automatically. Keep plugin commands, mappings, and setup in its
spec (`init`, `keys`, `opts`, or `config`). Use `lazy = true` with command/key
triggers for plugins that should load on demand; this config defaults to eager loading.

`lua/config/` contains editor setup and larger UI modules. `lua/utils/` contains
shared helpers such as theme colors and persisted state.

