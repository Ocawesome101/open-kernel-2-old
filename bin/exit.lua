-- logout: Kill the shell, spawn a login screen

local ok, err = loadfile("/bin/login.lua")
if not ok then
  return print(err)
end

os.kill(os.pid())
