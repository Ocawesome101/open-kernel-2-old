-- OpenRC init system --

local maxRunlevel = ... or 3

local rc = {}
local runlevel = 1
local shutdown = computer.shutdown

function computer.runlevel()
  return runlevel
end

rc._VERSION = "OpenRC 2.0.0-pre1"

kernel.log(rc._VERSION .. " starting up " .. kernel._VERSION)

kernel.log("init: Reading configuration from /etc/inittab")
local config = {}

local handle, err = fs.open("/etc/inittab")
if not handle then
  error("Failed to load init configuration: " .. err)
end

local data = ""
repeat
  local d = handle.read(math.huge)
  data = data .. (d or "")
until not d
handle.close()

local ok, err = load("return " .. data, "=openrc.parse-config", "bt", _G)
if not ok then
  error("Failed to parse init configuration: " .. err)
end

config = ok()

for k, v in ipairs(config.startup) do
  kernel.log("init: loading " .. v.id)
  local ok, err = loadfile(v.file)
  if not ok then
    error("Failed to load " .. v.id .. ": " .. err, -1)
  end
  local ok, err = pcall(ok)
  if not ok then
    error(v.id .. " crashed: " .. err, -1)
  end
end

kernel.log("init: Initializing cooperative scheduler")
do
  local tasks = {
    [1] = {
      coro = nil,
      id = "/sbin/init.lua",
      pid = 1,
      parent = 1
    }
  }
  local pid = 2
  local currentpid = 1
  local timeout = 0.25
  local event = require("event")

  function os.spawn(func, name)
    checkArg(1, func, "function")
    checkArg(2, name, "string")
    kernel.log("scheduler: Spawning task " .. tostring(pid) .. " with ID " .. name)
    tasks[pid] = {
      coro = coroutine.create(func),
      id = name,
      pid = pid,
      parent = currentpid
    }
    pid = pid + 1
    return pid - 1
  end

  function os.kill(pid)
    checkArg(1, pid, "number")
    if not tasks[pid] then return false, "No such process" end
    kernel.log("scheduler: Killing task " .. tasks[pid].id .. " (PID ".. tostring(pid) .. ")")
    tasks[pid] = nil
  end

  function os.tasks()
    local r = {}
    for k,v in pairs(tasks) do
      r[#r + 1] = k
    end
    return r
  end

  function os.pid()
    return currentpid
  end

  function os.info(pid)
    checkArg(1, pid, "number", "nil")
    local pid = pid or os.pid()
    if not tasks[pid] then return false, "No such process" end
    return {name = tasks[pid].id, parent = tasks[pid].parent, pid = tasks[pid].pid}
  end
  
  function os.start() -- Start the scheduler
    os.start = nil
    while #tasks > 0 do
      local eventData = {event.pull(nil, timeout)}
      for k, v in pairs(tasks) do
        if v.coro and coroutine.status(v.coro) ~= "dead" then
          currentpid = k
	  kernel.log("Current: " .. tostring(k))
          local ok, err = coroutine.resume(v.coro, table.unpack(eventData))
          if not ok and err then
            kernel.log("Task " .. v.id .. " (PID " .. tostring(k) .. "): " .. tostring(ok) .. " " .. tostring(err))
          end
        elseif v.coro then
          kernel.log("scheduler: Task " .. v.id .. " (PID " .. tostring(k) .. ") died")
          tasks[k] = nil
        end
      end
    end
    kernel.log("scheduler: all tasks exited")
    shutdown()
  end
end

if maxRunlevel >= 2 then
  runlevel = 2
  for k,v in ipairs(config.daemons) do
    kernel.log("init: Starting service " .. v.id)
    local ok, err = loadfile(v.file)
    if not ok then
      kernel.log("init: Service " .. v.id .. " failed: " .. err)
    else
      os.spawn(ok, v.file)
    end
  end
end

kernel.setlogs(false)
if maxRunlevel >= 2 then
  local ok, err = loadfile("/bin/login.lua")
  if not ok then
    error(err, -1)
  end

  os.spawn(ok, "/bin/login.lua")
else
  kernel.log("init: Starting single-user shell")
  local ok, err = loadfile("/bin/sh.lua")
  if not ok then
    error(err, -1)
  end

  os.spawn(ok, "/bin/sh.lua")
end

os.start()
