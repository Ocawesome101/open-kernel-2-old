-- Open Shell 2.0. Quite a bit better than Open Shell 1.0 --

local users = require("users")

_G.shell = {}

shell._VERSION = "Open Shell 2.0.0-pre2"

local env = {
  HOME = users.home(),
  PWD = users.home(),
  USER = users.user(),
  UID = users.uid(),
  PS1 = "\\w\\$ ",
  PATH = "/bin:/sbin:/usr/bin"
}

function os.getenv(var)
  checkArg(1, var, "string")
  return env[var]
end

function os.setenv(var, val)
  checkArg(1, var, "string")
  checkArg(1, val, "string")
  env[var] = val
end

local colors = { -- How to color escape sequences
  ["w"] = 0x55FF55,
  ["$"] = 0x00ACFF
}

local config = {}

kernel.log("sh: reading config")
local handle, err = fs.open(os.getenv("PWD") .. "/.shconfig")
if handle then
  local data = handle:readAll()
  handle:close()
  local ok, err = load("return " .. data, "=sh.parse-config", "bt", _G)
  if ok then
    local s, r = pcall(ok)
    if s then
      config = s
      colors = colors or config.colors
    end
  end
end

if not fs.exists(env.PWD) then
  fs.makeDirectory(env.PWD)
end

function shell.pwd()
  return env.PWD
end

function shell.setPwd(dir)
  checkArg(1, dir, "string")
  if fs.exists(dir) and fs.isDirectory(dir) then
    env.PWD = fs.clean(dir)
    return true
  elseif fs.exists(dir) then
    return false, dir .. ": Not a directory"
  else
    return false, dir .. ": No such file or directory"
  end
end

function shell.resolvePath(path)
  checkArg(1, path, "string")
  if path:sub(1, 1) == "/" then
    return path
  else
    if path:find("%.%.") then -- This is not yet supported
      return os.getenv("PWD")
    else
      return fs.clean(os.getenv("PWD") .. "/" .. path)
    end
  end
end

function shell.parse(...)
  local input = {...}
  local args, options = table.new(), {}
  for i=1, #input, 1 do
    if input[i]:sub(1, 1) == "-" then
      if input[i]:sub(1, 2) == "--" then
        options[input[i]:sub(3)] = true
      else
	for c in input[i]:sub(2):gmatch(".") do
          options[c] = true
	end
      end
    else
      args:insert(input[i])
    end
  end
  return args, options
end

function shell.exec(cmd, ...) -- It is probably best to call this with pcall, considering the liberal use of error().
  checkArg(1, cmd, "string")
  local exec = string.tokenize(" ", cmd, ...)
  local cmd = exec[1]
  local cmdPath = ""
  local function check(p)
    if fs.exists(p) then
      cmdPath = p
    end
  end
  for path in string.tokenize(":", env.PATH) do
    check(path .. "/" .. cmd .. ".lua")
    check(path .. "/" .. cmd)
    check(cmd)
    check(cmd .. ".lua")
  end
  if cmdPath == "" then
    return print("sh: " .. cmd .. ": command not found")
  end
  local ok, err = loadfile(cmdPath)
  if not ok then
    return error(err)
  end
  local s, r = pcall(function()return ok(table.unpack(exec, 2, #exec))end)
  if not s then
    return error(r)
  end
end

local function prompt()
  local p = ""
  local inEsc = false
  local PS1 = env.PS1
  for char in PS1:gmatch(".") do
    if char == "\\" then
      inEsc = (not inEsc)
      if not inEsc then
        p = p .. char
      end
    else
      if inEsc then
        gpu.setForeground(colors[char] or 0xFFFFFF)
        if char == "w" then
          io.write(env.PWD)
        elseif char == "$" then
          io.write(env.UID == 0 and "#" or "$")
        end
        inEsc = false
      else
        gpu.setForeground(colors["char"] or 0xFFFFFF)
        io.write(char)
      end
    end
  end
end

local function printError(...)
  local old = gpu.getForeground()
  gpu.setForeground(0xFF0000)
  print(...)
  gpu.setForeground(old)
end

coroutine.yield()
local history = table.new()
while true do
  prompt()
  local command = read(nil, history)
  if command and command ~= "" then
    history:insert(command)
    if #history > 16 then
      history:remove(1)
    end
    for cmd in string.tokenize(";", command) do
      gpu.setForeground(colors["char"] or 0xFFFFFF)
      local s,r = pcall(function()shell.exec(cmd)end)
      if not s then printError(r) end
    end
  end
  coroutine.yield()
end
