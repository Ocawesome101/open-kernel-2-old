-- Package management library. Having package management structured this way allows for custom frontends, similar to Arch's ALPM. --
-- Packages are stored as LZSS'd CPIO archives. --

local pkg = {}

local cpio = require("cpio")
local lzss = require("lzss")

local function extract(file, outfile)
  local handle = fs.open(file)
  local data = lzss.decompress(handle:readAll())
  handle:close()
  local out = fs.open(outfile, "w")
  out:write(data)
  out:close()
end

function pkg.installPackage(file)
  checkArg(1, file, "string")
  if not fs.exists(file) then
    return false, file .. ": No such file or directory"
  end
  if file:sub(-3) == ".lz" then
    extract(file, file:sub(1, -4))
    file = file:sub(1, -4)
    if file:sub(-5) ~= ".cpio" then
      file = file .. ".cpio"
    end
  else
    extract(file, file .. ".cpio")
    file = file .. ".cpio"
  end
  if file:sub(-5) == ".cpio" then
    cpio.extract(file, file:sub(1, -6))
    file = file:sub(1, -6)
  else
    cpio.extract(file, file .. ".d")
  end
end

return pkg
