-- Open Kernel 2 --

local flags = ... or {}

local bootAddress = computer.getBootAddress()

local filesystems = {}
local bootfs = component.proxy(bootAddress)
local init = flags.init or "/sbin/init.lua"

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
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)

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

local native_shutdown = computer.shutdown
computer.shutdown = function(b) -- make sure the log file gets properly closed
  kernel.log("Shutting down")
  bootfs.close(kernelLog)
  native_shutdown(b)
end

local native_error = error

local pullSignal = computer.pullSignal
local shutdown = computer.shutdown
function _G.error(err, level)
  if level == -1 or level == "__KPANIC__" then
    kernel.setlogs(true) -- The user should see this
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
        shutdown()
      end
    end
  else
    return native_error(err, level or 2)
  end
end

kernel.log("Initializing filesystems")

bootfs.remove("/mnt")

_G.fs = {}

local mounts = {
  {
    path = "/",
    proxy = bootfs
  }
}

kernel.log("Stage 1: helpers")
local function cleanPath(p)
  checkArg(1, p, "string")
  local path = ""
  for segment in p:gmatch("[^%/]+") do
    path = path .. "/" .. (segment or "")
  end
  if path == "" then
    path = "/"
  end
  return path
end

local function resolve(path) -- Resolve a path to a filesystem proxy
  checkArg(1, path, "string")
  local proxy
  local path = cleanPath(path)
  for i=1, #mounts, 1 do
    if mounts[i].path then
      local pathSeg = cleanPath(path:sub(1, #mounts[i].path))
      if pathSeg == mounts[i].path then
        path = cleanPath(path:sub(#mounts[i].path + 1))
        proxy = mounts[i].proxy
      end
    end
  end
  if proxy then
     return cleanPath(path), proxy
  end
end

kernel.__component = component

kernel.log("Stage 2: mounting, unmounting")
function fs.mount(addr, path)
  checkArg(1, addr, "string")
  checkArg(2, path, "string", "nil")
  local path = path or "/mnt/" .. (kernel.__component.invoke(addr, "getLabel") or addr:sub(1, 6))
  path = cleanPath(path)
  local p, pr = resolve(path)
  for _, data in pairs(mounts) do
    if data.path == path then
      if data.proxy.address == addr then
        return true, "Filesystem already mounted"
      else
        return false, "Cannot override mounts"
      end
    end
  end
  if kernel.__component.type(addr) == "filesystem" then
    kernel.log("Mounting " .. addr .. " on " .. path)
    if fs.makeDirectory then
      fs.makeDirectory(path)
    else
      bootfs.makeDirectory(path)
    end
    mounts[#mounts + 1] = {path = path, proxy = kernel.__component.proxy(addr)}
    return true
  end
  kernel.log("Failed mounting " .. addr .. " on " .. path)
  return false, "Unable to mount"
end

function fs.unmount(path)
  checkArg(1, path, "string")
  for k, v in pairs(mounts) do
    if v.path == path then
      kernel.log("Unmounting filesystem " .. path)
      mounts[k] = nil
      fs.remove(v.path)
      return true
    elseif v.proxy.address == path then
      kernel.log("Unmounting filesystem " .. v.proxy.address)
      mounts[k] = nil
      fs.remove(v.path)
    end
  end
  return false, "No such mount"
end

function fs.mounts()
  local rtn = {}
  for k,v in pairs(mounts) do
    rtn[k] = {path = v.path, address = v.proxy.address, label = v.proxy.getLabel()}
  end
  return rtn
end

kernel.log("Stage 3: standard FS API")
function fs.exists(path)
  checkArg(1, path, "string")
  local path, proxy = resolve(cleanPath(path))
  if not proxy.exists(path) then
    return false
  else
    return true
  end
end

function fs.open(file, mode)
  checkArg(1, file, "string")
  checkArg(2, mode, "string", "nil")
  if not fs.exists(file) and mode ~= "w"  then
    return false, "No such file or directory"
  end
  local mode = mode or "r"
  if mode ~= "r" and mode ~= "rw" and mode ~= "w" then
    return false, "Unsupported mode"
  end
  kernel.log("Opening file " .. file .. " with mode " .. mode)
  local path, proxy = resolve(file)
  local h, err = proxy.open(path, mode)
  if not h then
    return false, err
  end
  local handle = {}
  if mode == "r" or mode == "rw" or not mode then
    handle.read = function(n)
      return proxy.read(h, n)
    end
  end
  if mode == "w" or mode == "rw" then
    handle.write = function(d)
      return proxy.write(h, d)
    end
  end
  handle.close = function()
    proxy.close(h)
  end
  handle.handle = function()
    return h
  end
  return handle
end

fs.read = bootfs.read
fs.write = bootfs.write
fs.close = bootfs.close

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

  return proxy.isDirectory(path)
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
      local data = s.read(0xFFFF)
      d:write((data or ""))
    until not data
    s.close()
    d.close()
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
    local data = handle.read(0xFFFF)
    buffer = buffer .. (data or "")
  until not data
  handle.close()

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

  local data = ""
  repeat
    local d = handle.read(math.huge)
    data = data .. (d or "")
  until not d

  handle.close()

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

kernel.log("util: table.serialize")
function table.serialize(tbl) -- Readability is not a strong suit of this function's output.
  checkArg(1, tbl, "table")
  local rtn = "{"
  for k, v in pairs(tbl) do
    if type(k) == "string" then
      rtn = rtn .. "[\"" .. k .. "\"] = "
    else
      rtn = rtn .. "[" .. tostring(k) .. "] = "
    end
    if type(v) == "table" then
      rtn = rtn .. table.serialize(v)
    elseif type(v) == "string" then
      rtn = rtn .. "\"" .. tostring(v) .. "\""
    else
      rtn = rtn .. tostring(v)
    end
    rtn = rtn .. ","
  end
  rtn = rtn .. "}"
  return rtn
end

kernel.log("util: table.iter")
function table.iter(tbl) -- Iterate over the items in a table
  checkArg(1, tbl, "table")
  local i = 1
  return setmetatable(tbl, {__call = function()
    if tbl[i] then
      i = i + 1
      return tbl[i - 1]
    else
      return nil
    end
  end})
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
      i = i + 1
      return words[i - 1]
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

kernel.log("Loading init: " .. init)
local ok, err = loadfile(init)
if not ok then
  error(err, -1)
end

local s, e = pcall(ok, flags.runlevel)
if not s then
  error(e, -1)
end
