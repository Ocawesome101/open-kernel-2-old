-- makepkg: build OpenPM packages --

local args, options = shell.parse(...)

local verbose = options.v or options.verbose
local arch = (options.l52 and "Lua 5.2") or (options.l53 and "Lua 5.3") or (options.all and "all") or "all"

local config = require("config")

if #args < 3 or options.h or options.help then
  print("usage: makepkg [--l52|--l53|--all] DIR PACKAGE NAME")
  print("Archive all files in DIR into package PKG.acv, and autogenerate a package.cfg with the name set to NAME.")
  print("If one of --l52, --l53, or --all is specified, the package architecture will be set to Lua 5.2, Lua 5.3, or all, respectively.")
  return
end

local dir = shell.resolve(args[1])

local out = shell.resolve(args[2])

local files = fs.list(dir)

local pkgcfg = {
  name = args[3],
  arch = arch,
  files = {}
}

print("Creating package configuration")
for file in table.iter(files) do
  if verbose then print("Adding file " .. file .. " as " .. fs.clean("/" .. file)) end
  pkgcfg.files[file] = fs.clean("/" .. file)
end

config.save(pkgcfg, dir .. "/package.cfg")

print("Archiving package")
acv.pack(dir, out)
