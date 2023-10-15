local rt = require("rust-tools")
local M = {}

local cache = {
  last_debuggable = nil,
  last_runnable = nil,
  last = nil,
}

-- @param action
M.set_last_runnable = function(choice, result)
  cache.last_runnable = { choice, result }
  cache.last = "runnable"
end

-- @param args
M.set_last_debuggable = function(args)
  cache.last_debuggable = args
  cache.last = "debuggable"
end

M.execute_last_debuggable = function()
  local args = cache.last_debuggable
  cache.last = "debuggable"
  if args then
    rt.dap.start(args)
  else
    rt.debuggables.debuggables()
  end
end

M.execute_last_runnable = function()
  local action = cache.last_runnable
  cache.last = "runnable"
  if action then
    rt.runnables.run_command(action[1], action[2])
  else
    rt.runnables.runnables()
  end
end

M.execute_last = function()
  if cache.last == "debuggable" then
    M.execute_last_debuggable()
  else
    M.execute_last_runnable()
  end
end

return M
