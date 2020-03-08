-- Event stuff --

local event = {}
local computer = require("computer")

local pullSignal, pushSignal = computer.pullSignal, computer.pushSignal

event.push = function(e, ...)
  kernel.log("events: Pushing signal " .. e)
  pushSignal(e, ...)
end

event.listeners = {
  ["component_added"] = function(addr, ctype)
    if ctype == "filesystem" then
      fs.mount(addr)
    elseif ctype == "eeprom" then
      package.loaded["eeprom"] = component.proxy(addr)
    end
    event.push("device_added", addr, ctype) -- for devfs processing. Bit hacky.
  end,
  ["component_removed"] = function(addr, ctype)
    if ctype == "filesystem" then
      fs.unmount(addr)
    elseif ctype == "eeprom" then
      package.loaded["eeprom"] = nil
    end
    event.push("device_removed", addr) -- again, for devfs processing, bit hacky, yadda yadda yadda
  end
}

event.listen = function(evt, func)
  checkArg(1, evt, "string")
  checkArg(2, func, "function")
  if event.listeners[evt] then
    return false, "Event listener already in place for event " .. evt
  else
    event.listeners[evt] = func
    return true
  end
end

event.cancel = function(evt)
  checkArg(1, evt, "string")
  if not event.listeners[evt] then
    return false, "No event listener for event " .. evt
  else
    event.listeners[evt] = nil
    return true
  end
end

event.pull = function(filter, timeout)
  checkArg(1, filter, "string", "nil")
  checkArg(2, timeout, "number", "nil")
--  kernel.log("events: pulling event " .. (filter or "<any>") .. ", timeout " .. (tostring(timeout) or "none"))
  if timeout then
    local e = {pullSignal(timeout)}
--    kernel.log("events: got " .. (e[1] or "nil"))
    if event.listeners[e[1]] then
      event.listeners[e[1]](table.unpack(e, 2, #e))
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
        event.listeners[e[1]](table.unpack(e, 2, #e))
      end
    until e[1] == filter or filter == nil
    return table.unpack(e)
  end
end

package.loaded["event"] = event
