local M = {}

local function path_for(name)
  return vim.fn.stdpath("state") .. "/" .. name
end

function M.read(name, default)
  local f = io.open(path_for(name), "r")
  if not f then
    return default
  end
  local content = f:read("*a")
  f:close()
  if content == nil or content == "" then
    return default
  end
  -- Trim whitespace/newlines — a trailing "\n" (manual edit, another tool
  -- appending) would otherwise get passed straight into things like
  -- vim.cmd.colorscheme("ayu-dark\n"), which errors rather than trimming.
  return vim.trim(content)
end

function M.write(name, value)
  local f = io.open(path_for(name), "w")
  if not f then
    return false
  end
  f:write(value)
  f:close()
  return true
end

return M
