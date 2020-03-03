-- This script just loads the kernel. That's all it does. You can go now. --

-- Only edit this table! --
local flags = {
  init = "/sbin/init.lua",
  runlevel = 2, -- Runlevel the system should attempt to reach
  disableLogging = false, -- Enable this option if you're running from a read-only FS
  verbose = true -- Whether to log boot or not, otherwise you will get a black screen until the shell is loaded
}

local addr, invoke = computer.getBootAddress(), component.invoke
local p = computer.pullSignal

local function loadfile(file)
  local handle = assert(invoke(addr, "open", file))
  local buffer = ""
  repeat
    local data = invoke(addr, "read", handle, math.huge)
    buffer = buffer .. (data or "")
  until not data
  invoke(addr, "close", handle)
  return load(buffer, "=" .. file, "bt", _G)
end

local ok, err = loadfile("/boot/kernel.lua")
if not ok then
  error(err)
end
ok(flags)

while true do
  local sig, _, n = p()
  if sig == "key_down" then
    if string.char(n) == "r" then
      computer.shutdown(true)
    end
  end
end
