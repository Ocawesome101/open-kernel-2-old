-- cat: print the contents of a file --

local args, options = shell.parse(...)

if #args < 1 then
  error("Usage: cat FILE")
end

local handle, err = fs.open(shell.resolvePath(args[1]))
if not handle then error(err) end

local data = handle:readAll()
handle:close()

print(data)
