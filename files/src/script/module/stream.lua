-- CSVファイル出力ストリーム
package.path = "script/module/?.lua"
require("profiler")

local name = ...           -- 第一引数がモジュール名
local _m = {}              -- メンバ関数を補樹威するテーブル
local _meta = {__index=_m} 
local _v = {}              -- プライベート変数(selfをキーとするテーブル)
package.loaded[name] = _m  -- 二度目のrequire()はこれが返される
_G[name] = _m              -- グローバルに登録しておく

local perf = profiler:new() -- 性能計測

------------------------------------------------
-- private
------------------------------------------------

local function check(_self, result, msg)
	if result == false or result == nil then
		print_table(_self.tbl)
		_self:offset(-127)
		_self:dump()
		assert(false, "assertion failed! msg=".. msg)
	end
	
	if _self.break_address ~= nil then
		if cur() > _self.break_address - 127 then
			print_on(true)
		end
		if cur() > _self.break_address + 126 then
			assert(false)
		end
	end
end

------------------------------------------------
-- public
------------------------------------------------

function _m:new(file_name)
	assert(type(file_name)=="string")
	print("open("..file_name..")")
	obj = {tbl={}}
	--_v[obj] = {}
	setmetatable(obj, _meta )

	obj.file_name = file_name
	obj.stream = Bitstream.new()
	assert(obj.stream:open(file_name))
	return obj
end

function _m:print()	
	printf("file_name : %s", self.file_name)
	printf("file_size : 0x%08x", self:size())
	printf("cursor    : 0x%08x(%d)", self:cur(), self:cur())
	printf("remain    : 0x%08x", self:size() - self:cur())
	perf:print()
end

function _m:size()	
	return self.stream:file_size()
end

function _m:dump()	
	self.stream:dump(256)
end

function _m:cur()	
	return self.stream:cur_byte(), self.stream:cur_bit()
end

function _m:get(name)	
	return self.tbl[name]
end

function _m:rbit(name, size)
--perf:enter("_rbit")
	local val = self.stream:read_bit(name, size)
--perf:leave("_rbit")
--perf:enter("_check")
	check(self, val, "rbit:"..name)
--perf:leave("_check")
--perf:enter("_tbl")
	self.tbl[name] = val
--perf:leave("_tbl")
	return val
end

function _m:rbyte(name, size)
	local val = self.stream:read_byte(name, size)
	check(self, val, "rbyte:"..name)
	self.tbl[name] = val
	return val
end

function _m:rstr(name, size)	
 	local val = self.stream:read_string(name, size)
	check(self, val, "rstr:"..name)
	self.tbl[name] = val
	return val
end

function _m:cbit(name, size, comp)	
	local val = self.stream:comp_bit(name, size, comp)
	check(self, val, "cbit:"..name)
	self.tbl[name] = val
	return val
end

function _m:cbyte(name, size, comp)	
	local val = self.stream:comp_byte(name, size, comp)
	check(self, val, "cbyte:"..name)
	self.tbl[name] = val
	return val
end

function _m:cstr(name, size, comp)
 	local val = self.stream:comp_string(name, size, comp)
	check(self, val, "cstr:"..name)
	self.tbl[name] = val
	return val
end

function _m:sbyte(char)	
	local ofs = self.stream:search_byte(char)
	check(self, ofs, "sbyte:"..char)
	return ofs
end

function _m:sstr(pattern)
	local str = ""
	if string.match(pattern, "[0-9a-f][0-9a-f]") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	local ofs = self.stream:search_byte_string(str, #str)
	check(self, ofs, "sstr:"..pattern)
	return ofs	
end

function _m:offset(ofs)
	self.stream:offset_byte(ofs)
end

function _m:seek(pos)
	return self.stream:seek(pos, 0)
end
function _m:wbyte(filename, size)	
	local ret = self.stream:copy_byte(filename, size)
	check(self, ret, "wbyte:"..filename)
end

function _m:write(filename, pattern)
	local str = ""
	if string.match(pattern, "[0-9][0-9] ") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	local ret = self.stream:write(filename, str, #str)
	check(self, ret, "write:"..filename)
end

function _m:enable_print(b)	
	return self.stream:enable_print(b)
end

function _m:bit_seek(size)	
	return self.stream:offset_by_bit(size)
end

function _m:set_exit(address)	
	self.break_address = address
end

function _m:little_endian(enable)	
	assert(type(enable) == "boolean")
	self.stream:little_endian(enable)
end



--function progress()
--	local p = math.modf(cur()/file_size() * 100)
--	if math.modf(p % 10) == 0 and progress <= p then
--		gs_prev_progress = gs_prev_progress + 10
--		print(progress.."%", os.clock().."sec.")
--		profiler:print()
--	end
--end

