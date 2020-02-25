-- Event stuff --

-- TODO: Maybe fix event listeners?

local event = {}
local computer = require("computer")

event.listeners = {
  ["component_added"] = function(addr, ctype)
    if ctype == "filesystem" then
      fs.mount(addr)
    end
  end,
  ["component_removed"] = function(addr, ctype)
    if ctype == "filesystem" then
      fs.unmount(addr)
    end
  end
}

local pullSignal, pushSignal = computer.pullSignal, computer.pushSignal

event.pull = function(filter, timeout)
--  kernel.log("events: pulling event " .. (filter or "<any>") .. ", timeout " .. (tostring(timeout) or "none"))
  if timeout then
    local e = {pullSignal(timeout)}
--    kernel.log("events: got " .. (e[1] or "nil"))
    if event.listeners[e[1]] then
      pcall(function()event.listeners[e[1]](table.unpack(e, 2, #e))end)
    end
    if e[i] == filter or not filter then
      return table.unpack(e)
    end
  else
    local e = {}
    repeat
      e = {pullSignal()}
--      kernel.log("events: got " .. e[1])
      if event.listeners[e[1]] then
        pcall(function()event.listeners[e[1]](table.unpack(e, 2, #e))end)
      end
    until e[1] == filter or filter == nil
    return table.unpack(e)
  end
end

event.push = function(e, ...)
  kernel.log("events: Pushing signal " .. e)
  pushSignal(e, ...)
end

lib.loaded["event"] = event
