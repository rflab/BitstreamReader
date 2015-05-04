dofile("lib/mylib.lua")


open("test.wav")
dump (0, 256)

check("riff", 5, false)

local a = testclass.new();
--print_table_all(_G)

print("--------------")
print_table(getmetatable(a))
--print_table_all(a)

a = {}
collectgarbage("collect")

--riff = readbyte("riff", 5, true)
--riff = readbyte("riff", 5, false)

--[[
print("hogehoge")
	
for key, val in pairs(Test) do
   print(key, val)
end

local p = Test.new( 3 );
local p2 = Test.new( 100 );

print "*** p"
meta = getmetatable(p)

for key, val in pairs(meta) do
   print(key, val)
end

print "*** p2"
meta = getmetatable(p2)

for key, val in pairs(meta) do
   print(key, val)
end

	p:test()
	p2:test()
	p:test2()
	p2:test2()
	
	p={}
	
	
function test()
	local p = Test.new( 5 );
	p:test()
	
	local p2 = Test.new( 3 );
	p:test()
	p2:test()

	collectgarbage("collect")
end


--p.glue( p );
--p:glue();
--local p2 = Test.new( 3 );
--]]
