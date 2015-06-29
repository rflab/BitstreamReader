-- ストリームクラス
-- newの引数に応じてファイル、バッファ、FIFOが切り替わる
-- ファイル、バッファはほぼすべてのメソッドを使用可能だが、
-- FIFOはシークが必要な処理がバインドされておらずエラーになる

------------------------------------------------
-- class
------------------------------------------------
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
	if 0 == 0 then
		if result == false or result == nil then
			print_table(_self.tbl)
			_self:offset(-127)
			_self:dump()
			_self:offset(127)
			assert(false, "assertion failed! msg=".. msg)
		end
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

function _m:new(param, openmode)
	self.index = self.index or 0
	self.index = self.index + 1
	obj = {tbl={}, name}
	--_v[obj] = {}
	setmetatable(obj, _meta )

	if type(param) == "string" then
		print("open stream ("..param..")")
		obj.stream = FileBitstream:new(param, openmode)
		obj.name = "file["..self.index.."]"
		obj.file_name = param
	elseif type(param) == "number" then
		print("create fifo stream ("..hexstr(param)..")")
		obj.stream = Fifo:new(param)
		obj.name = "fifo["..self.index.."]"
		obj.file_name = "no_file_name"
	else
		print("create buffer ()")
		obj.stream = Buffer:new()
		obj.name = "buffer["..self.index.."]"
		obj.file_name = "no_file_name"
	end

	obj.stream:little_endian(false)
	obj.is_little_endian = false
	return obj
end

function _m:print()	
	printf("name    : %s", self.file_name)
	printf("size    : 0x%08x", self:get_size())
	printf("cursor  : 0x%08x(%d)", self:cur(), self:cur())
	printf("remain  : 0x%08x", self:get_size() - self:cur())
	perf:print()
end

function _m:print_table()	
	print_table(self.tbl)
end

function _m:get_size()	
	return self.stream:size()
end

function _m:dump(size)	
	self.stream:dump(size or 128)
end

function _m:cur()	
	return self.stream:byte_pos(), self.stream:bit_pos()
end

function _m:get(name)	
	local val = self.tbl[name]
	assert(val, "get nil value \""..name.."\"")
	return val
end

function _m:peek(name)
	local val = self.tbl[name]
	return val
end

function _m:reset(name, value)	
	self.tbl[name] = value
end

function _m:rbit(name, size)
	local val = self.stream:read_bit(name, size)
	check(self, val, "rbit:"..name)
	self.tbl[name] = val
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

function _m:rexp(name)
	local val = self.stream:read_expgolomb(name)
	check(self, val, "rexp:"..name)
	self.tbl[name] = val
	return val
end

function _m:cbit(name, size, comp)	
	return self.stream:comp_bit(name, size, comp)
end

function _m:cbyte(name, size, comp)	
	return self.stream:comp_byte(name, size, comp)
end

function _m:cstr(name, size, comp)
 	return self.stream:comp_string(name, size, comp)
end

function _m:cexp(name, size, comp)
 	return self.stream:comp_expgolomb(name, size, comp)
end

function _m:lbyte(size)	
 	local val = self.stream:look_byte(size)
	check(self, val, "lbyte:")
	return val
end

function _m:lbit(size)	
 	local val = self.stream:look_bit(size)
	check(self, val, "lbit:")
	return val
end

function _m:lexp(size)	
 	local val = self.stream:look_expgolomb(size)
	check(self, val, "lbit:")
	return val
end

function _m:fbyte(char, advance, end_offset)	
	if advance == nil then advance = true end
	if end_offset == nil then end_offset = 0x7fffffff end
	local ofs = self.stream:find_byte(char, advance, end_offset)
	check(self, ofs, "fbyte:"..char)
	return ofs
end

function _m:fstr(pattern, advance, end_offset)
	if advance == nil then advance = true end
	if end_offset == nil then end_offset = 0x7fffffff end
	local str = pat2str(pattern)
	local ofs = self.stream:find_byte_string(str, #str, advance, end_offset)
	check(self, ofs, "fstr:"..pattern)
	return ofs	
end

function _m:seek(byte, bit)
	assert(self.stream:seekpos(byte, bit or 0))
	return true
end

function _m:seekoff(byte, bit)
	assert(self.stream:seekoff(byte, bit or 0))
	--if byte ~= nil then assert(self.stream:seekoff_byte(byte)) end
	--if bit  ~= nil then assert(self.stream:seekoff_bit(bit)) end
	return true
end

function _m:putc(c)
	self.stream:put_char(c)
end

function _m:write(pattern)
	local str = ""
	if string.match(pattern, "^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	self.stream:write(str, #str)
end

function _m:tbyte(name, size, target, advance)
	if advance == nil then advance = true end	
	if type(target) == "string" then
		return transfer_to_file(target, self.stream, size, advance)
	else
		self.stream:transfer_byte(name, target.stream, size, advance)
	end
end

function _m:sub_stream(name, size, advance)	
	if advance == nil then advance = true end
	local b = Buffer:new()
	print(size)
	self.stream:transfer_byte(name, b, size, advance)
	return b
end

function _m:enable_print(b)	
	return self.stream:enable_print(b)
end

function _m:ask_enable_print()
	print("print analyze for "..self.name.."? [y/n]")
	local enalbe = io.read() == "y" and true or false
	self.stream:enable_print(enalbe)
	return enalbe
end

function _m:set_exit(address)	
	self.break_address = address
end

function _m:little_endian(enable)
	if type(enable) ~= "boolean" then 
		return self.stream.is_little_endian
	else
		self.is_little_endian = enable
		self.stream:little_endian(enable)
	end
end

--function progress()
--	local p = math.modf(cur()/get_size() * 100)
--	if math.modf(p % 10) == 0 and progress <= p then
--		gs_prev_progress = gs_prev_progress + 10
--		print(progress.."%", os.clock().."sec.")
--		profiler:print()
--	end
--end
