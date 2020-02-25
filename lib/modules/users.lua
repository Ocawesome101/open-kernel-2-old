-- User system --

local users = {}

local user = "root"
local uid = 0

local data = require("data")
if not data then
  error("users: Data card required!", -1)
end

local passwd = {
  ["root"] = {
    uid = 0,
    pass = "^¿Z­õúŠù¯h€­e~×P°ý±-Ç@FÇ+ ¯¬" -- Good luck guessing this!
  }
}

kernel.log("users: Reading /etc/passwd")
local handle, err = fs.open("/etc/passwd")
if not handle then
  kernel.log("users: /etc/passwd: " .. err)
else
  local data = handle:readAll()
  handle:close()
  local ok, err = load("return " .. data, "=users.parse-passwd", "bt", _G)
  if not ok then
    kernel.log("users: Failed to parse /etc/passwd: " .. err)
  else
    local s, r = pcall(ok)
    if not s then
      kernel.log("users: Failed to parse /etc/passwd: " .. r)
    else
      passwd = r
    end
  end
end

local users = {}

function users.login(name)
  if not passwd[name] then
    return false, "No such user"
  end
  kernel.log("users: Attempting login as " .. name)
  local tries = 3
  while tries > 0 do
    write("password: ")
    local password = read("")
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

function users.uid()
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
