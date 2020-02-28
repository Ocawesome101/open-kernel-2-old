-- ocmake: reimplementation of make --
local args, options = {...}
local config = require("config")
local target = args[1] or "all"
local dir = shell.pwd()
if not fs.exists(fs.clean(dir .. "/OMakefile")) then
  print("ocmake: *** No OMakefile found. Stop.")
  return
end
local makefile = config.load(fs.clean(dir .. "/OMakefile"))
if not makefile[target] then
  print("ocmake: *** No rule to make target '" .. target .. "'. Stop.")
  return
end
local function make(t)
  if not t then
    print("ocmake: *** No rule to make target '" .. t .. "'")
  end
  for dep in table.iter(makefile[t].deps) do
    make(makefile[dep])
  end
  for command in table.iter(makefile[t].exec) do
    print(command)
    local ok, ret = pcall(function()return shell.exec(command)end)
    if not ok then
      print("ocmake: *** Target '" .. t .. "' failed: " .. err)
      return
    end
    print(ret)
  end
end
make(target)
