-- clear: clear the screen --

local w,h = gpu.getResolution()
gpu.fill(1,1,w,h," ")
gpu.setCursorPos(1,1)
