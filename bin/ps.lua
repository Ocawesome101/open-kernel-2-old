-- ps: list running processes --

local processes = os.tasks()

print("PID  PARENT  NAME")
for _, pid in pairs(processes) do
  local pinfo = os.info(pid)
  print(pinfo.pid, "  ", pinfo.parent, "     ", pinfo.name)
end
