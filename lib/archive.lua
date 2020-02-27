-- Simple, custom archive format. --

local acv = {}

local function getData(line)
  checkArg(1, line, "string")
  local data = {false, nil, nil} -- isDefinition, type, path. All paths are treated as relative.
  if line:sub(1, 9) == "--ACVDATA" then
    data[1] = true
    if line:sub(10, 23) == " type=DIR,path=" then
      data[2] = "directory"
      data[3] = line:sub(24)
    elseif line:sub(9,24) == " type=FILE,path=" then
      data[2] = "file"
      data[3] = line:sub(25)
    end
  end
  return data, line
end

function acv.unpack(file, dest)
  checkArg(1, file, "string")
  checkArg(2, dest, "string")
  fs.makeDirectory(dest)
  local handle, err = fs.open(file)
  if not handle then
    return false, err
  end
  local data = handle:readAll()
  handle:close()
  local outhandle
  for line in string.tokenize("\n", data) do
    local linedata, text = getData(line)
    if not linedata[1] then
      if outhandle then
        outhandle:write(text .. "\n")
      end
    else
      if linedata[2] == "directory" then
	fs.makeDirectory(dest .. "/" .. linedata[3])
      else
	if outhandle then outhandle:close() end
	outhandle = fs.open(dest .. "/" .. linedata[3], "w")
      end
    end
  end
end

local function writeData(dir, out, recursed, rdir)
  for file in table.iter(fs.list(dir)) do
    if fs.isDirectory(dir .. "/" .. (recursed and rdir .. "/" or "") .. file) then
      out:write("--ACVDATA type=DIR,path=" .. (recursed and rdir .. "/" or "") .. file) -- This line is cursed
      writeData(dir, out, true, (recursed and rdir .. "/" or "") .. file)
    else
      out:write("--ACVDATA type=FILE,path=" .. (recursed and rdir .. "/" or "") .. file) -- This one too
      local h = fs.open(dir .. "/" .. (recursed and rdir .. "/" or "") .. file) -- Did I mention this line is really cursed?
      out:write(h:readAll() or "")
      h:close()
    end
  end
end

function acv.pack(dir, dest)
  checkArg(1, dir, "string")
  checkArg(2, dest, "string")
  if not fs.exists(dir) then
    return false, dir .. ": No such file or directory"
  end
  local output = fs.open(dest, "w")
  writeData(dir, output, false, nil)
  output:close()
  return true
end

return acv
