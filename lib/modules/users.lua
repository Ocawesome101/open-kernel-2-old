-- User system --

local user = "root"
local uid = 0

local data = require("data")
if not data then
  error("users: Data card required!", -1)
end

local passwd = {}

kernel.log("users: Reading /etc/passwd")
local handle, err = fs.open("/etc/passwd")
if not handle then
  kernel.log("users: /etc/passwd: " .. err)
  return
end

local users = {}

function users.login(name)
  if not passwd[name] then
    return false, "No such user"
  end
  kernel.log("users: Attempting login as " .. name)
  local tries = 3
  while tries > 0 do
    local password = read("*")
    local password = data.sha256(password)
    if passwd[name].pass == password then
      user = name
      uid = passwd[name].uid
      return true
    else
      tries = tries - 1
    end
  end
end

function users.user()
  return user
end

function user.uid()
  return uid
end

function users.home()
  if user ~= "root" and uid ~= 0 then
    return "/home/" .. user
  else
    return "/root"
  end
end

lib.loaded["users"] = users
