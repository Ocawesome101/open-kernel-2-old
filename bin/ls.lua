-- ls: list the contents of a directory --

local args, options = shell.parse(...)

local color = (options.nocolor and false) or true
local hidden = options.a or options.all or false
local fileColor = 0xFFFFFF
local scriptColor = color and 0x33FF33 or 0xFFFFFF
local dirColor = color and 0x00BDFF or 0xFFFFFF

--local dir = args[1] and shell.resolvePath(args[1]) or shell.pwd()

--if not fs.exists(dir) then return print("ls: " .. dir .. ": No such file or directory") end

local function printFile(file)
  if file:sub(1, 1) ~= "." or hidden then
    if file:sub(-1) == "/" then
      gpu.setForeground(dirColor)
    elseif file:sub(-4) == ".lua" then
      gpu.setForeground(scriptColor)
    else
      gpu.setForeground(fileColor)
    end
    print(file)
  end
end

if #args > 0 then
  for i=1, #args, 1 do
    local dir = shell.resolvePath(args[i])
    if not fs.exists(dir) then print("ls: " .. dir .. ": No such file or directory")
    else
      gpu.setForeground(0xFFFFFF)
      print(dir .. ":")
      local files = fs.list(dir)

      table.sort(files)

      for i=1, #files, 1 do
        printFile(files[i])
      end
      print("")
    end
  end
else
  local files = fs.list(shell.pwd()) or {}

  table.sort(files)

  for i=1, #files, 1 do
    printFile(files[i])
  end
end
