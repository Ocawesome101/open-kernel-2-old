-- Event stuff --

local event = {}

local pullSignal, pushSignal = computer.pullSignal, computer.pushSignal

event.pull = function(filter, timeout)
  kernel.log("events: pulling event " .. (filter or "<any>") .. ", timeout " .. (tostring(timeout) or "none"))
  if timeout then
    local e = {pullSignal(timeout)}
    kernel.log("events: got " .. (e[1] or "nil"))
    if e[i] == filter or not filter then
      return table.unpack(e)
    end
  else
    local e = {}
    repeat
      e = {pullSignal()}
      kernel.log("events: got " .. e[1])
    until e[1] == filter or filter == nil
    return table.unpack(e)
  end
end

event.push = function(e, ...)
  kernel.log("events: Pushing signal " .. e)
  pushSignal(e, ...)
end

lib.loaded["event"] = event
