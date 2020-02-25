-- cd: change directory --

local args, options = shell.parse(...)

if #args < 1 then
  error("Usage: cd DIRECTORY")
end

local dir = fs.clean(shell.resolvePath(args[1]))

local ok, err = shell.setPwd(dir)
if not ok then error(err) end
