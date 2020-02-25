-- Listen for events and act on them --

while true do
  local e, p1, p2, p3, p4 = coroutine.yield()
  if e == "component_added" then
    fs.mount(p1)
  elseif e == "component_removed" then
    fs.unmount(p1)
  end
end
