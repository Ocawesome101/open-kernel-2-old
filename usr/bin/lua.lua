-- A Lua interpreter. Pretty basic. --

local args, options = shell.parse(...)

local LUA_ENV = table.copy(_G)

local exit = false

function LUA_ENV.exit()
  exit = true
end

gpu.setForeground(0xFFFF00)
print(_VERSION)

local history = table.new()
while not exit do
  gpu.setForeground(0xFFFF00)
  write("lua> ")
  local inp = read(nil, history)
  history:insert(inp)
  if #history > 16 then
    history:remove(1)
  end
  local ok, ret = pcall(function()return load(inp,"=stdin","t",LUA_ENV)()end)
  if type(ret) == "table" then
    print(table.serialize(ret))
  else
    print(ret)
  end
end
