-- Mostly just a read() function --

local event = require("event")

function _G.read(replace, history)
  local str = ""
  local x, y = gpu.getCursorPos()
  local w, h = gpu.getResolution()
  local cursorX = 1
  local function redraw(showCursor)
    gpu.setCursorPos(x, y)
    write((" "):rep(#str + 2))
    gpu.setCursorPos(x, y)
    write(str)
    if showCursor then
      local tx, ty = gpu.getCursorPos()
      local char, fg, bg = gpu.get(tx, ty)
      gpu.setForeground(bg)
      gpu.setBackground(fg)
      gpu.set(tx+1, ty, char)
      gpu.setForeground(fg)
      gpu.setBackground(bg)
    end
  end
  while true do
    redraw(true)
    local e, _, id, special = event.pull()
    if e == "key_down" then
      if id >= 32 and i <= 126 then
        str = str .. string.char(id)
--        cursorX = cursorX + 1
      elseif id == 8 then -- Backspace
        str = str:sub(1, cursorX - 1) .. str:sub(cursorX + 1)
--        cursorX = cursorX - 1
      elseif id == 13 then -- Enter
        redraw(false)
        write("\n")
        return str
      end
    elseif e == "clipboard" then
      str = str .. id
    end
  end
end
