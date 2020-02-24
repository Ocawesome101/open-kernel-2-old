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

local function genLibError(n)
  local err = "Library '" .. n .. "' not found:\n  no field lib.loaded['" .. n .. "']"
  for path in string.tokenize(lib.path) do
    err = err .. "\n  no file '" .. fs.clean(path .. "/" .. n) .. "'"
  end
  return err
end

function lib.search(name) -- Search the module path for a lib
  checkArg(1, name, "string")
  local paths = string.tokenize(lib.path)
  for path in paths do
    path = fs.clean(path)
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
  return s
end

function _G.require(library)
  checkArg(1, library, "string")
  if library:sub(1, 1) == "/" then
    return dofile(library)
  elseif lib.loaded[library] then
    return lib.loaded[library]
  end
  local path, err = lib.search(library)
  if not path then
    return false, err
  end
  return dofile(path)
end
