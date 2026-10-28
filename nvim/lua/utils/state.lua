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
  local function failed(err)
    vim.notify(
      ("failed to write state file '%s': %s"):format(name, tostring(err)),
      vim.log.levels.WARN,
      { title = "state.lua" }
    )
    return false
  end
  local ok, err = pcall(vim.fn.mkdir, vim.fn.stdpath("state"), "p")
  if not ok then return failed(err) end
  local f, open_err = io.open(path_for(name), "w")
  if not f then return failed(open_err) end
  local written, write_err = f:write(value)
  local closed, close_err = f:close()
  if not written then return failed(write_err) end
  if not closed then return failed(close_err) end
  return true
end

return M
