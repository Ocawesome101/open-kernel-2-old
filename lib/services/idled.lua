-- idled: for when your system is just idling --

local computer = require("computer")

while true do
  if computer.runlevel() >= 2 then
    kernel.log("idled: not needed in multi-user mode")
    os.kill(os.pid()) -- We aren't needed
  end
  coroutine.yield()
  local shellRunning = false
  local tasks = os.tasks()
  for k, v in pairs(tasks) do
    if os.info(v).name == "/bin/sh.lua" then
      shellRunning = true
    end
  end
  if not shellRunning and computer.runlevel() == 1 then -- The shell has been exited, and we're in single-user mode!
    kernel.log("idled: shell is not running. Restarting shell.")
    local ok, err = loadfile("/bin/sh.lua")
    if not ok then
      kernel.log("idled: error " .. err .. " loading /bin/sh.lua!")
      kernel.log("waiting 5s before retrying")
      os.sleep(5)
    else
      os.spawn(ok, "/bin/sh.lua")
    end
  end
end
