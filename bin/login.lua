-- Login screen --

local users = require("users")

while true do
  write("login: ")
  local name = read()
  local ok, err = users.login(name)
  if not ok then
    print(err)
  else
    local ok, err = loadfile("/bin/sh.lua")
    if not ok then
      kernel.log(err)
    else
      os.spawn(ok, "shell")
      os.kill(os.pid())
    end
  end
  coroutine.yield()
end
