-- Module system. Not the most memory-friendly, but it works. And, it's (mostly) standard-Lua-compliant! --

_G.package = {}

package.path = "/lib/?.lua;/lib/?/init.lua;/usr/lib/?.lua;/usr/lib/?/init.lua;/usr/lib/compat/?.lua;/usr/lib/compat/?/init.lua"

package.loaded = {
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

local function resolveModule(path, n)
  return path:gsub("%?", n)
end

local function genLibError(n)
  local err = "Library '" .. n .. "' not found:\n  no field package.loaded['" .. n .. "']"
  for path in string.tokenize(";", package.path) do
    err = err .. "\n  no file '" .. resolveModule(path, n) .. "'"
    err = err .. "\n  no file '" .. resolveModule(path, n) .. "'"
  end
  return err
end

-- TODO: Do something with path, sep, rep
function package.searchpath(name, path, sep, rep) -- Search the module path for a package
  checkArg(1, name, "string")
  local paths = string.tokenize(";", package.path)
  for path in paths do
    path = fs.clean(path)
    module = resolveModule(path, name)
    if fs.exists(module) then
      return module
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
  if library:sub(1, 1) == "/" then
    return dofile(library)
  elseif package.loaded[library] then
    return package.loaded[library]
  else
    local path, err = package.searchpath(library)
    if not path then
      return false, err
    end
    local a, r = dofile(path)
    if a and type(a) == "table" then package.loaded[library] = a end
    return a, r
  end
end
