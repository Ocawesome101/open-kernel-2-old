-- Open Shell 2.0. Quite a bit better than Open Shell 1.0 --

local users = require("users")

_G.shell = {}

shell._VERSION = "Open Shell 2.0.0-pre2"

local pwd = users.home()

local PS1 = "\\w" .. (users.uid() == 0 and "# " or "$ ")
local PATH = "/bin:/sbin:/usr/bin"

if not fs.exists(pwd) then
  fs.makeDirectory(pwd)
end

function shell.pwd()
  return pwd
end

function shell.setPwd(dir)
  checkArg(1, dir, "string")
  if fs.exists(dir) then
    pwd = dir
    return true
  else
    return false
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
        options[input[i]:sub(2)] = true
      end
    else
      args:insert(input[i])
    end
  end
  return args, options
end

function shell.exec(...) -- It is probably best to call this with pcall, considering the liberal use of error().
  local exec = string.tokenize(" ", ...)
  local cmd = exec[1]
  local cmdPath = ""
  local function check(p)
    if fs.exists(p) then
      cmdPath = p
    end
  end
  for path in string.tokenize(":", PATH) do
    check(path .. "/" .. cmd .. ".lua")
    check(path .. "/" .. cmd)
    check(path)
    check(path .. ".lua")
  end
  if cmdPath == "" then
    return error("Command not found")
  end
  local ok, err = loadfile(cmdPath)
  if not ok then
    return error(err)
  end
  local s, r = pcall(function()return ok(table.unpack(exec, 2))end)
  if not s then
    return error(r)
  end
end

local function prompt()
  local p = ""
  local inEsc = false
  for char in PS1:gmatch(".") do
    if char == "\\" then
      inEsc = (not inEsc)
      if not inEsc then
        p = p .. char
      end
    else
      if inEsc then
        if char == "w" then
          p = p .. PWD
        elseif char == "$" then
          p = p .. (users.uid() == 0 and "#" or "$")
        end
        inEsc = false
      else
        p = p .. char
      end
    end
  end
  return p
end

local function printError(...)
  local old = gpu.getForeground()
  gpu.setForeground(0xFF0000)
  print(...)
  gpu.setForeground(old)
end

while true do
  local command = read()
  if command then
    local s,r = pcall(function()shell.exec(command)end)
    if not s then printError(r) end
  end
end
