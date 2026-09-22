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
  return vim.trim(content)
end

function M.write(name, value)
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  local f = io.open(path_for(name), "w")
  if not f then
    -- The only realistic cause is a missing/unwritable stdpath("state") dir.
    -- Every caller previously ignored the boolean return value, so this was
    -- failing completely silently.
    vim.notify(
      ("failed to write state file '%s' (stdpath('state') not writable?)"):format(name),
      vim.log.levels.WARN,
      { title = "state.lua" }
    )
    return false
  end
  f:write(value)
  f:close()
  return true
end

return M
