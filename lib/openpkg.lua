-- Package management library. Having package management structured this way allows for custom frontends, similar to Arch's ALPM. --
-- Packages are stored using custom archives. --

local pkg = {}

local acv = require("archive")
local config = require("config")

local function getPackages()
end

function pkg.installPackage(file)
  checkArg(1, file, "string")
  if not fs.exists(file) then
    return false, file .. ": No such file or directory"
  end
  if file:sub(-4) == ".acv" then
    acv.unpack(file, file:sub(-4))
  else
    return false, "File " .. file .. " does not have the .acv extension"
  end
  local path = file:sub(-4)
  if not fs.exists(path .. "/package.cfg") then
    return false, "Package contains no package.cfg"
  end
  local pkgConf, err = config.load(path .. "/package.cfg")
  if not pkgConf then
    return false, err
  end
  if not (pkgConf.name and pkgConf.files and pkgConf.arch) then
    return false, "Invalid package.cfg: missing name, files, or arch"
  end
  local name = pkgConf.name
  local files = pkgConf.files
  local arch = pkgConf.arch
  if arch ~= "Lua 5.3" and arch ~= "Lua 5.2" and arch ~= "all" then
    return false, "Invalid package architecture " .. arch
  end
  if arch ~= _VERSION and arch ~= "all" then
    return false, "Package architecture " .. arch .. " does not match CPU architecture"
  end
  
end

return pkg
