# Neovim Config

Standalone Neovim configuration powered by `lazy.nvim` (not LazyVim).

## Configuration structure

Add plugin specs as Lua files returning a table in `lua/plugins/`; Lazy imports
that directory automatically. Keep plugin commands, mappings, and setup in its
spec (`init`, `keys`, `opts`, or `config`). Use `lazy = true` with command/key
triggers for plugins that should load on demand; this config defaults to eager loading.

`lua/config/` contains editor setup and larger UI modules. `lua/utils/` contains
shared helpers such as theme colors and persisted state.

