-- device fs. similar to the FS mount system, but works on more components --

local dfs = {}
local component = require("component")
local event = require("event")

local devices = {}

local handles = {}

local function randAddr()
  local str = ""
  for i=1, 32, 1 do
    local char = string.char(math.random(97, 102)) -- get a random hex char
    local num = tostring(math.floor(math.random(0, 9)))
    if math.random(0, 100) > 50 then -- randomization :D
      str = str .. num
    else
      str = str .. char
    end
  end
  str = table.concat({str:sub(1,8),str:sub(9,12),str:sub(13,16),str:sub(17,20),str:sub(21,32)}, "-")
  return str
end

dfs.type = "filesystem"
dfs.address = randAddr()

local types = {
  ["filesystem"] = "fs",
  ["gpu"] = "gpu",
  ["screen"] = "scrn",
  ["keyboard"] = "kbd",
  ["eeprom"] = "eeprom",
  ["redstone"] = "rs",
  ["computer"] = "comp",
  ["disk_drive"] = "sr",
  ["internet"] = "net",
  ["modem"] = "net"
}

local function addDfsDevice(addr, dtype)
  local path = "/" .. (types[dtype] or dtype)
  local n = 0
  kernel.log("devfs: adding device /dev" .. path)
  for k,v in pairs(devices) do
    if v.proxy and v.path and v.proxy.address then
      if v.proxy.address == addr then
        return
      end
      if v.proxy.type == dtype then
        n = n + 1
      end
    end
  end
  path = path .. tostring(n)
  devices[#devices + 1] = {path = path, proxy = component.proxy(addr)}
end

event.listen("device_added", addDfsDevice)

local function resolveDevice(d)
  for k,v in pairs(devices) do
    if v.path == d then
      return v
    end
  end
  return false, "No such device"
end

local function makeHandleEEPROM(dev, mode)
  checkArg(1, dev, "string")
  checkArg(2, mode, "string", "nil")
  local dproxy = resolveDevice(dev)
  if dproxy.type ~= "eeprom" then return false, "Device is not an EEPROM" end
  local d = {}
  function d.read()
    return dproxy.getData()
  end
  handles[#handles + 1] = d
  return #handles
end

function dfs.open(dev, mode)
  checkArg(1, dev, "string")
  checkArg(2, mode, "string", "nil")
  local device, dtype = resolveDevice(dev)
  if dtype == "eeprom" then
    local handle = makeHandleEEPROM(device, mode)
    return handle
  else
    return false, "Only EEPROMs are currently supported for opening"
  end
end

function dfs.exists(f)
  checkArg(1, f, "string")
  kernel.log("devfs: checking existence " .. f)
  if resolveDevice(f) or fs.clean(f) == "/" then
    return true
  else
    return false
  end
end

function dfs.list()
  local l = {}
  for k,v in pairs(devices) do
    l[#l + 1] = fs.clean(v.path):sub(2)
  end
  return l
end

function dfs.permissions()
  return 0
end

function dfs.lastModified()
  return 0
end

function dfs.close(num)
  handles[num] = nil
end

function dfs.getLabel() return "devfs" end
function dfs.setLabel() return true end

component.create(dfs)
fs.mount(dfs.address, "/dev")

for addr, ctype in component.list() do
  addDfsDevice(addr, ctype)
end

lib.loaded["devfs"] = {
  getAddress = function(device)
    local proxy = resolveDevice(device)
    return proxy.address
  end
}
