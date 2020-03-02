-- Listen for events and act on them --

local event = require("event")

while true do
  local e, p1, p2, p3, p4 = event.pull(nil, 0.25)
  if e == "component_added" then
    fs.mount(p1)
  elseif e == "component_removed" then
    fs.unmount(p1)
  end
  coroutine.yield()
end
