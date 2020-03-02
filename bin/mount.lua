-- mount: get fs mounts / mount filesystems --

local args, options = shell.parse(...)

local devfs = require("devfs")

if #args < 1 then
  local mts = fs.mounts()
  for k,v in pairs(mts) do
    print((v.label or v.address) .. " on " .. v.path)
  end
  return
end
