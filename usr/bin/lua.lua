-- A Lua interpreter. Pretty basic. --

local args, options = shell.parse(...)

local LUA_ENV = table.copy(_G)

gpu.setForeground(0xFFFF00)
print(_VERSION)

local history = table.new()
while true do
  gpu.setForeground(0xFFFF00)
  io.write("lua> ")
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
