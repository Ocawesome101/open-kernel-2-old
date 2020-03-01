-- Login screen --

local users = require("users")

for _,t in pairs(os.tasks()) do
  if os.info(t).name == "/bin/sh.lua" then
    return print("login: shell is already running!")
  end
end

while true do
  io.write("login: ")
  local name = read()
  local ok, err = users.login(name)
  if not ok then
    print(err)
  else
    local ok, err = loadfile("/bin/sh.lua")
    os.spawn(ok, "/bin/sh.lua")
    coroutine.yield()
    local shell = true
    while shell do
      shell = false
      local t = os.tasks()
      for k,v in pairs(t) do
	if os.info(v).name == "/bin/sh.lua" then
	  shell = true
	end
      end
      coroutine.yield()
    end
  end
end
