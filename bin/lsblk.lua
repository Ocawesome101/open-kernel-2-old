-- lsblk: list installed filesystems --

local args, options = shell.parse(...)

local component = require("component")

local bytes = options.b or options.bytes or false

local mts = fs.mounts()

local function findMount(a)
  for k,v in pairs(mts) do
    if v.address == a then
      return v.path
    end
  end
  return ""
end

print("NAME                 SIZE    RO    MOUNTPOINT")

for addr in component.list("filesystem") do
  local size = component.invoke(addr, "spaceTotal")
  if bytes then
    size = tostring(size) .. "B"
  else
    size = tostring(math.floor(size/1024/1024)) .. "M"
  end
  local name = component.invoke(addr, "getLabel") or addr:sub(1, 6)
  local mtpath = findMount(addr)
  local ro = component.invoke(addr, "isReadOnly")
  while #name < 20 do
    name = name .. " "
  end
  while #size < 7 do
    size = size .. " "
  end
  print(name, size, ro, mtpath)
end
