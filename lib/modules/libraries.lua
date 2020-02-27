-- Module system. Not the most memory-friendly, but it works. --

_G.lib = {}

lib.path = "/lib;/usr/lib;/usr/include"

lib.loaded = {
  ["_G"] = _G,
  ["string"] = string,
  ["table"] = table,
  ["math"] = math,
  ["coroutine"] = coroutine,
  ["component"] = table.copy(component),
  ["computer"] = table.copy(computer),
  ["unicode"] = table.copy(unicode)
}

_G.component, _G.computer, _G.unicode = nil, nil, nil

local function genLibError(n)
  local err = "Library '" .. n .. "' not found:\n  no field lib.loaded['" .. n .. "']"
  for path in string.tokenize(";", lib.path) do
    err = err .. "\n  no file '" .. fs.clean(path .. "/" .. n) .. "'"
    err = err .. "\n  no file '" .. fs.clean(path .. "/" .. n .. ".lua") .. "'"
  end
  return err
end

function lib.search(name) -- Search the module path for a lib
  checkArg(1, name, "string")
  local paths = string.tokenize(";", lib.path)
  for path in paths do
    path = fs.clean(path)
--    kernel.log(path .. "/" .. name .. ".lua")
    if fs.exists(path .. "/" .. name .. ".lua") then
      return fs.clean(path .. "/" .. name .. ".lua")
    end
    if fs.exists(path .. "/" .. name) then
      return fs.clean(path .. "/" .. name)
    end
  end
  return false, genLibError(name)
end

function _G.dofile(file)
  checkArg(1, file, "string")
  local ok, err = loadfile(file)
  if not ok then
    return false, err
  end
  local s, r = pcall(ok)
  if not s then
    return false, r
  end
  return r
end

function _G.require(library)
  checkArg(1, library, "string")
--  kernel.log(tostring(lib.loaded[library]))
  kernel.log("libmanager: looking up module '" .. library .. "'")
  if library:sub(1, 1) == "/" then
    return dofile(library)
  elseif lib.loaded[library] then
    return lib.loaded[library]
  else
    local path, err = lib.search(library)
    if not path then
      kernel.log("libmanager: requiring module '" .. library .. "' failed: " .. err)
      return false, err
    end
    local a, r = dofile(path)
    if a and type(a) == "table" then lib.loaded[library] = a end
    return a, r
  end
end
