-- mount: get fs mounts / mount filesystems --

local args, options = shell.parse(...)

local devfs = require("devfs")

local usage = [[mount (c) 2020 Ocawesome101 under the MIT license.
usage: mount /dev/fsX /path
   or: mount -h, --help
]]

if #args < 1 then
  local mts = fs.mounts()
  for k,v in pairs(mts) do
    print((v.label and "\"" .. v.label .. "\"" or v.address) .. " on " .. v.path)
  end
  return
end

local dfs = args[1]
local mtpath = (args[2] and shell.resolve(args[2])) or "/mnt/"
local addr = devfs.getAddress(dfs)

if not fs.exists(dfs) then
  return print("mount: " .. mtpath .. ": special device " .. dfs .. " does not exist")
end

if not fs.exists(mtpath) then
  fs.makeDirectory(mtpath)
end

local ok, err = fs.mount(addr, mtpath)
if not ok then
  print("mount: " .. err)
end
