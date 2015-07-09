-- table for global var declaration checking
local gdef = {}
local gdef_enabled = nil

-- the function to define global vars
function global(n, v)
  if not gdef_enabled then
    error("calling function global() when explicit-globals not enabled",2)
  end
  if gdef[n] == true then
    error("re-definition of global \"" .. tostring(n) .. "\"",2)
  end
  rawset(_G, n, v)
  gdef[n] = true
  
  return v
end

local function registerglobal(t,n,v)
  gdef[n] = true
  rawset(t,n,v)
end

-- forbid implicit definition of global vars
function use_explicit_globals( is_explicit_in_main_chunk )

  -- set metatable for gloval environment
  local mt = getmetatable(_G)
  if mt == nil then
    mt = {}
    setmetatable(_G, mt)
  end

  -- include implicitly-declared globals in gdef table, 
  -- in case some of it becomes nil and __index,__newindex be called.
  -- drawback: if the value is nil now, it will not be included.
  for k,v in pairs(_G) do
    gdef[k] = true
  end

  mt.__newindex = function (t,n,v)
    if gdef[n] ~= nil then -- declared global
      rawset(t,n,v);return
    end
    local upfuncinfo = debug.getinfo(2,"S")
    if upfuncinfo == nil then
      registerglobal(t,n,v);return
    end
    local w = upfuncinfo.what
    if w == "C" then -- in C chunk
      registerglobal(t,n,v);return
    end
    if ( not is_explicit_in_main_chunk and w == "main" ) then -- in main chunk
      registerglobal(t,n,v);return
    end
    if type(v) == "function" then
      -- funtcion value
      if w == "main" then 
        -- declatration of functions in main chunk is ok.
        registerglobal(t,n,v);return
      else
        error("assignment of undeclared global function \"" .. tostring(n) .. "\" outside of main chunk. use global(\"var\", val)", 2)
      end
    else
      -- not function value
      error("assignment of undeclared global \"" .. tostring(n) .. "\". use global(\"var\", val)", 2)
    end
  end
  mt.__index = function (t,n)
    local upfuncinfo = debug.getinfo(2,"S")
    if gdef[n] == nil and upfuncinfo ~= nil and upfuncinfo.what ~= "C" then
      error("attempt to use undeclared global \"" .. tostring(n) .. "\". use global(\"var\", val)", 2)
    end
    return rawget(t, n)
  end
  gdef_enabled = true
end

-- back to normal, implicit global declaration.
function use_implicit_globals()
  local mt = getmetatable(_G)
  if mt ~= nil then
    mt.__newindex = nil
    mt.__index = nil
  end
  gdef_enabled = nil
end

use_explicit_globals( true ) -- use explicit globals from start, except main chunk
