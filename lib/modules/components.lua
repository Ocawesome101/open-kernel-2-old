-- Set up requireable proxies for components, with a few exceptions --

for addr, ctype in component.list() do
  if ctype ~= "filesystem" and ctype ~= "gpu" and ctype ~= "screen" and ctype ~= "keyboard" and ctype ~= "sandbox" and not lib.loaded[ctype] then
    kernel.log("components: creating proxy: type " .. ctype .. ", address " .. addr)
    lib.loaded[ctype] = component.proxy(addr)
  end
end
