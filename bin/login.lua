-- Login screen --

while true do
  write("login: ")
  local name = read()
  local ok, err = users.login(name)
  if not ok then
    print(err)
  else
    local ok, err = loadfile("/bin/sh.lua")
    if not ok then
      error(err)
    else
      os.spawn(ok, "shell")
    end
  end
end
