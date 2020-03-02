-- Virtual-component API. MUST be loaded before libmanager! --

local vcomponents = {}

local list, invoke, proxy, comtype = component.list, component.invoke, component.proxy, component.type

local ps = computer.pushSignal

function component.create(componentAPI)
  checkArg(1, componentAPI, "table")
  kernel.log("vcomponent: Adding component: type " .. componentAPI.type .. ", addr " .. componentAPI.address)
  vcomponents[componentAPI.address] = componentAPI
  ps("component_added", componentAPI.type, componentAPI.address)
end

function component.remove(addr)
  if vcomponents[addr] then
    ps("component_removed", vcomponents[addr].type, vcomponents[addr].address)
    vcomponents[addr] = nil
    return true
  end
  return false
end

function component.list(ctype, match)
  for k,v in pairs(vcomponents) do
    if v.type == ctype then
      return k
    end
  end
  return list(ctype, match)
end

function component.invoke(addr, operation, ...)
  checkArg(1, addr, "string")
  if vcomponents[addr] then
    if vcomponents[addr][operation] then
      return vcomponents[addr][operation](...)
    end
  end
  return invoke(addr, operation, ...)
end

function component.proxy(addr)
  checkArg(1, addr, "string")
  if vcomponents[addr] then
    return vcomponents[addr]
  else
    return proxy(addr)
  end
end

function component.type(addr)
  checkArg(1, addr, "string")
  if vcomponents[addr] then
    return vcomponents[addr].type
  else
    return comtype(addr)
  end
end

kernel.__component = component
