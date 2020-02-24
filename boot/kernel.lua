-- Open Kernel 2 --

local flags = ... or {}

local bootAddress = computer.getBootAddress()

local filesystems = {}
local bootfs = component.proxy(bootAddress)

-- component proxies
for addr, ctype in component.list() do
  if ctype == "gpu" then
    _G.gpu = _G.gpu or component.proxy(addr)
  elseif ctype == "filesystem" then
    filesystems[addr] = component.proxy(addr)
  elseif ctype == "screen" then
    if gpu then
      gpu.bind(addr)
    end
  end
end

gpu.setResolution(gpu.maxResolution())

local x, y = 1, 1
local w, h = gpu.getResolution()

gpu.fill(1, 1, w, h, " ")

function gpu.getCursorPos()
  return x, y
end

function gpu.setCursorPos(X,  Y)
  checkArg(1, X, "number")
  checkArg(2, Y, "number")
  x, y = X, Y
end

function gpu.scroll(amount)
  checkArg(1, amount, "number")
  gpu.copy(1, 1, w, h, 0, 0 - amount)
  gpu.fill(1, h, w, amount, " ")
end

function write(str)
  local function newline()
    x = 1
    if y + 1 <= h then
      y = y + 1
    else
      gpu.scroll(1)
      y = h
    end
  end
  while #str > 0 do
    local space = str:match("^[ \t]+")
    if space then
      gpu.set(x, y, space)
      x = x + #space
      str = str:sub(#space + 1)
    end

    local newLine = str:match("^\n")
    if newLine then
      newline()
      str = str:sub(2)
    end

    local word = str:match("^[^ \t\n]+")
    if word then
      str = str:sub(#word + 1)
      if #word > w then
        while #str > 0 do
          if x > w then
            newline()
          end
          gpu.set(x, y, text)
          x = x + #text
          text = text:sub((w - x) + 2)
        end
      else
        if x + #word > w then
          newline()
        end
        gpu.set(x, y, word)
        x = x + #word
      end
    end
  end
end

function print(...)
  local args = {...}
  for i=1, #args, 1 do
    write(tostring(args[i]))
    if i < #args then
      write(" ")
    end
  end
  write("\n")
end

local uptime = computer.uptime
local function time() -- Format the computer's uptime so we can print it nicely
  local u = tostring(uptime()):sub(1, 7)
  local c = u:find("%.") or 4
  if c == 7 then
    u = u:sub(2) .. "0"
  end
  while #u < 7 do
    u = "0" .. u
  end
  return u
end

_G.kernel = {}

kernel._VERSION = "Open Kernel 2.0.0-rc1"

bootfs.rename("/boot/log", "/boot/log.old")

local kernelLog, err = bootfs.open("/boot/log", "w")
local verbose = flags.verbose or true

function kernel.log(msg)
  local m = "[" .. time() .. "] " .. msg
  bootfs.write(kernelLog, m .. "\n")
  if verbose then
    print(m)
  end
end

function kernel.setlogs(boolean)
  checkArg(1, boolean, "boolean")
  verbose = boolean
end

kernel.log(kernel._VERSION .. " booting on " .. _VERSION)

kernel.log("Total memory: " .. tostring(math.floor(computer.totalMemory() / 1024)) .. "K")
kernel.log("Free memory: " .. tostring(math.floor(computer.freeMemory() / 1024)) .. "K")

local shutdown = computer.shutdown
computer.shutdown = function(b) -- make sure the log file gets properly closed
  kernel.log("Shutting down")
  bootfs.close(kernelLog)
  shutdown(b)
end

local native_error = error

local pullSignal = computer.pullSignal
function _G.error(err, level)
  if level == -1 or level == "__KPANIC__" then
    verbose = true -- The user should see this
    kernel.log(("="):rep(25))
    kernel.log("PANIC: " .. err)
    local traceback = debug.traceback(nil, 2)
    for line in traceback:gmatch("[^\n]+") do
      kernel.log(line)
    end
    kernel.log("Press S to shut down.")
    kernel.log(("="):rep(25))
    while true do
      local e, _, id = pullSignal()
      if e == "key_down" and string.char(id):lower() == "s" then
        computer.shutdown()
      end
    end
  else
    return native_error(err, level)
  end
end

kernel.log("Initializing filesystems")

_G.fs = {}

local mounts = {["/"] = bootfs}

kernel.log("Stage 1: helpers")
local function cleanPath(p)
  checkArg(1, p, "string")
  local path = ""
  for segment in p:gmatch("[^%/]+") do
    path = path .. "/" .. segment
  end
  return path
end

local function resolve(path) -- Resolve a path to a filesystem proxy
  checkArg(1, path, "string")
  local proxy
  local path = cleanPath(path)
  for p,cp in pairs(mounts) do
    if path:sub(1, #p) == p then
      path = path:sub(#p + 1)
      proxy = cp
    end
  end
  if proxy then
    return cleanPath(path), proxy
  else
    return false, "No filesystem mounted"
  end
end

kernel.log("Stage 2: mounting, unmounting, mount-listing")
function fs.mount(addr, path)
  checkArg(1, addr, "string")
  checkArg(2, path, "string", "nil")
  local path = path or "/mnt/" .. addr:sub(1, 6)
  path = cleanPath(path)
  local p, pr = resolve(path)
  if p and pr and p ~= path:sub(2) then -- If we didn't just get the beginning / stripped
    return false, "Sub-mounts are not yet supported"
  end
  if mounts[path] then
    if mounts[path].address == addr then
      return true
    else
      return false, "Cannot overwrite an existing mount"
    end
  else
    if component.type(addr) == "filesystem" then
      kernel.log("Mounting " .. addr .. " on " .. path)
      mounts[path] = component.proxy(addr)
    end
  end
  return false, "Unable to mount"
end

function fs.unmount(path)
  checkArg(1, path, "string")
  for k, v in pairs(mounts) do
    if v == path then
      kernel.log("Unmounting filesystem " .. path)
      mounts[k] = nil
      fs.remove(k)
      return true
    elseif k == path then
      kernel.log("Unmounting filesystem " .. v)
      mounts[k] = nil
      fs.remove(k)
    end
  end
  return false, "No such mount"
end

function fs.mounts()
  local rtn = {}
  for k,v in pairs(mounts) do
    rtn[k] = v.address
  end
  return rtn
end

kernel.log("Stage 3: standard FS API")
function fs.exists(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)
  if proxy.exists(path) then
    return true
  else
    return false
  end
end

function fs.open(file)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  if not fs.exists(file) then
    return false, "File not found"
  end
  local mode = mode or "r"
  if mode ~= "r" and mode ~= "rw" and mode ~= "w" then
    return false, "Unsupported mode"
  end
  local path, proxy = resolve(file)
  local handle, err = proxy.open(file, mode)
  if not handle then
    return false, err
  end
  local returnHandle = {}
  function returnHandle:close()
    returnHandle = nil
    return proxy.close(handle)
  end
  function returnHandle:rawHandle()
    return handle
  end
  if mode == "r" or mode == "rw" then
    function returnHandle:read(amount)
      checkArg(1, amount, "number")
      return proxy.read(handle, amount)
    end
    function returnHandle:readAll()
      local buffer = ""
      repeat
        local data = proxy.read(handle, 0xFFFF)
        buffer = buffer .. (data or "")
      until not data
      return buffer
    end
  end
  if mode == "w" or mode == "rw" then
    function returnHandle:write(data)
      checkArg(1, data, "string")
      return proxy.write(handle, data)
    end
  end
  return returnHandle
end

function fs.list(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)

  return proxy.list(path)
end

function fs.remove(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)

  return proxy.remove(path)
end

function fs.spaceUsed(path)
  checkArg(1, path, "string", "nil")
  local path, proxy = resolve(path or "/")

  return proxy.spaceUsed()
end

function fs.makeDirectory(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)

  return proxy.makeDirectory(path)
end

function fs.isReadOnly(path)
  checkArg(1, path, "string", "nil")
  local path, proxy = resolve(path or "/")

  return proxy.isReadOnly()
end

function fs.spaceTotal(path)
  checkArg(1, path, "string", "nil")
  local path, proxy = resolve(path or "/")

  return proxy.spaceTotal()
end

function fs.isDirectory(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)

  return proxy.isDirectory()
end

function fs.rename(source, dest)
  checkArg(1, source, "string")
  checkArg(2, dest, "string")
  local spath, sproxy = resolve(source)
  local dpath, dproxy = resolve(dest)

  if sproxy == dproxy then -- Easy way out
    return sproxy.rename(spath, dpath)
  else
    local s, err = sproxy.open(spath, "r")
    if not s then
      return false, err
    end
    local d, err = dproxy.open(dpath, "w")
    if not d then
      s:close()
      return false, err
    end
    repeat
      local data = s:read(0xFFFF)
      d:write((data or ""))
    until not data
    s:close()
    d:close()
    sproxy.remove(spath)
  end
end

function fs.lastModified(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)

  return proxy.lastModified(path)
end

function fs.getLabel(path)
  checkArg(1, path, "string", "nil")
  local path, proxy = resolve(path or "/")

  return proxy.getLabel()
end

function fs.setLabel(label, path)
  checkArg(1, label, "string")
  checkArg(2, "string", "nil")
  local path, proxy = resolve(path or "/")

  return proxy.setLabel(label)
end

function fs.size(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(path)

  return proxy.size(path)
end

for addr, _ in component.list("filesystem") do
  if addr ~= bootfs.address then
    if component.invoke(addr, "getLabel") == "tmpfs" then
      fs.mount(addr, "/tmp")
    else
      fs.mount(addr)
    end
  end
end

kernel.log("Reading /etc/fstab")

-- /etc/fstab specifies filesystems to mount in locations other than /mnt, if any. Note that this is fileystem-specific and as such not included by default.

local fstab = {}

local handle, err = fs.open("/etc/fstab", "r")
if not handle then
  kernel.log("Failed to read fstab: " .. err)
else
  local buffer = ""
  repeat
    local data = handle:read(0xFFFF)
    buffer = buffer .. (data or "")
  until not data
  handle:close()

  local ok, err = load("return " .. buffer, "=kernel.parse_fstab", "bt", _G)
  if not ok then
    kernel.log("Failed to parse fstab: " .. err)
  else
    fstab = ok()
  end
end

for k, v in pairs(fstab) do
  for a, t in component.list() do
    if a == k and t == "filesystem" then
      fs.mount(k, fstab[v])
    end
  end
end

kernel.log("Setting up utilities")

kernel.log("util: loadfile")
function _G.loadfile(file, mode, env)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  local file = cleanPath(file)
  local mode = mode or "bt"
  local env = env or _G
  kernel.log("loadfile: loading " .. file .. " with mode " .. mode)
  local handle, err = fs.open(file, "r")
  if not handle then
    return false, err
  end

  local data = handle:readAll()

  return load(data, "=" .. file, mode, env)
end

kernel.log("util: table.new")
function table.new(...)
  local tbl = {...} or {}
  return setmetatable(tbl, {__index = table})
end

kernel.log("util: table.copy")
function table.copy(tbl)
  checkArg(1, tbl, "table")
  local rtn = {}
  for k,v in pairs(tbl) do
    rtn[k] = v
  end
  return rtn
end

kernel.log("util: string.tokenize")
function string.tokenize(sep, ...)
  checkArg(1, sep, "string")
  local line = table.concat({...}, sep)
  local words = table.new()
  for word in line:gmatch("[^" .. sep .. "]+") do
    words:insert(word)
  end
  local i = 1
  setmetatable(words, {__call = function() -- iterators! they're great!
    if words[i] then
      return words[i]
    else
      return nil
    end
  end})
  return words
end

kernel.log("util: os.sleep")
local pullSignal = computer.pullSignal
function os.sleep(time)
  local dest = uptime() + time
  repeat
    pullSignal(dest - uptime())
  until uptime() >= dest
end

kernel.log("util: fs.clean")
function fs.clean(path)
  checkArg(1, path, "string")
  return cleanPath(path)
end

kernel.log("Loading /sbin/init.lua")
local ok, err = loadfile("/sbin/init.lua")
if not ok then
  error(err, -1)
end

local s, e = pcall(ok, flags.runlevel)
if not s then
  error(e, -1)
end