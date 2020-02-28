-- Mostly just a read() function --

local event = require("event")

function _G.read(replace, history, default)
  checkArg(1, replace, "string", "nil")
  checkArg(2, history, "table", "nil")
  checkArg(3, default, "string", "nil")
  local str = default or ""
  if replace then replace = replace:sub(1,1) end

  local histPos
  local history = history or {}
  local pos, scroll = #str, 0
  local w = gpu.getResolution()
  local sx = gpu.getCursorPos()

  local function redraw(cursor)
    local cursorPos = sx + pos - scroll
    if sx + cursorPos >= w then
      scroll = (sx + pos) - w
    elseif cursorPos < 0 then
      scroll = pos
    end

    local cx, cy = gpu.getCursorPos()
    gpu.setCursorPos(sx, cy)
    write((" "):rep(w - sx))
    gpu.setCursorPos(sx, cy)
    if replace then
      write(replace:rep(#str):sub(scroll + 1, w - sx - 1))
    else
      write(str:sub(scroll + 1, (w - sx) - 1))
    end
    if cursor then
      local oldc = gpu.get(cursorPos,cy)
      local oldf = gpu.getForeground()
      local oldb = gpu.getBackground()
      gpu.setForeground(oldb)
      gpu.setBackground(oldf)
      gpu.set(cursorPos,cy,oldc)
      gpu.setForeground(oldf)
      gpu.setBackground(oldb)
    end

    gpu.setCursorPos(sx + pos - scroll, cy)
  end

  local c = true
  while true do
    local e, _, p1, p2 = event.pull(nil, 0.7)
    if not e then
      redraw(c)
      c = not c
    else
      c = true
      redraw(c)
    end
    if e == "key_down" then
      redraw(true)
      if p1 > 0 then
        if p1 >= 32 and p1 < 127 then
          str = str:sub(1, pos) .. string.char(p1) .. str:sub(pos + 1)
          pos = pos + 1
          redraw(true)
        elseif p1 == 13 then -- Enter
          redraw(false)
          break
        elseif p1 == 8 then -- Backspace
          if pos > 0 then
            str = str:sub(1, pos - 1) .. str:sub(pos + 1)
            pos = pos - 1
            if scroll > 0 then scroll = scroll - 1 end
           redraw(true)
          end
        end
      elseif p1 == 0 then
        if p2 == 203 then -- Left arrow
          if pos > 0 then
            pos = pos - 1
            redraw(true)
          end
        elseif p2 == 205 then -- Right arrow
          if pos < #str then
            pos = pos + 1
            redraw(true)
          end
        elseif p2 == 200 or p2 == 208 then -- Up or down arrow
          if p2 == 200 then -- Up arrow
            if histPos == nil then
              if #history > 0 then
                histPos = #history
              end
            elseif histPos > 1 then
              histPos = histPos - 1
            end
          else -- Down arrow
            if histPos == #history then
              histPos = nil
            elseif histPos ~= nil then
              histPos = histPos + 1
            end
          end
          if histPos then
            str = history[histPos]
            pos, scroll = #str, 0
          else
            str = ""
            pos, scroll = 0, 0
          end
        end
      end
    elseif e == "screen_resized" then
      w = gpu.getResolution()
      redraw(true)
    elseif e == "clipboard" then
      str = str .. p1
    end
  end
  write("\n")
  return str
end
