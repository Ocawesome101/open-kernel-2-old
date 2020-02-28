-- mv: move files --

local args, options = shell.parse(...)

if #args < 2 then
  return print("mv: missing file operand")
end

fs.rename(shell.resolvePath(args[1]), shell.resolvePath(args[2]))
