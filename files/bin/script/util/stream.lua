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
	if result == false then
		print_table(_self.tbl)
		_self:dump()
		assert(false, "assertion failed! msg=".. msg)
	end
end

------------------------------------------------
-- public
------------------------------------------------

-- openmodeはfopenとちょっと違う
-- "+" -> 読み書き
-- "i" -> 読み込み
-- "w" -> 書き込み
-- "a" -> 書き込みは末尾追加追加
-- "b" -> バイナリモード
function _m:new(param, openmode)
	self.index = self.index or 0
	self.index = self.index + 1
	obj = {tbl={}, name}
	--_v[obj] = {}
	setmetatable(obj, _meta )

	if type(param) == "string" then
		assert(openmode~=nil)
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

function _m:print(...)
	if self.print_enabled then
		print(...)
	end
end

function _m:print_status()	
	printf("name    : %s", self.file_name)
	printf("size    : 0x%08x", self:get_size())
	printf("cursor  : 0x%08x(%d)", self:cur(), self:cur())
	printf("remain  : 0x%08x", self:get_size() - self:cur())
	perf:print()
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
	assert(false, "unsupported")
	local val = self.tbl[name]
	assert(val, "get nil value \""..name.."\"")
	return val
end

function _m:peek(name)
	assert(false, "unsupported")
	local val = self.tbl[name]
	return val
end

function _m:reset(name, value)	
	assert(false, "unsupported")
	self.tbl[name] = value
end

function _m:gbit(size)
	return self.stream:read_bit("", size)
end

function _m:gbyte(size)
	return self.stream:read_byte("", size)
end

function _m:gstr(size)	
 	return self.stream:read_string("", size)
end

function _m:gexp()
	return self.stream:read_expgolomb("")
end

function _m:rbit(name, size)
	local val = self.stream:read_bit(name, size)
	-- check(self, val, "rbit:"..name)
	-- self.tbl[name] = val
	return val
end

function _m:rbyte(name, size)
	local val = self.stream:read_byte(name, size)
	-- check(self, val, "rbyte:"..name)
	-- self.tbl[name] = val
	return val
end

function _m:rstr(name, size)	
 	local val = self.stream:read_string(name, size)
	-- check(self, val, "rstr:"..name)
	-- self.tbl[name] = val
	return val
end

function _m:rexp(name)
	local val = self.stream:read_expgolomb(name)
	-- check(self, val, "rexp:"..name)
	-- self.tbl[name] = val
	return val
end

function _m:cbit(name, size, comp)	
	return self.stream:comp_bit(name, size, comp)
end

function _m:cbyte(name, size, comp)	
	return self.stream:comp_byte(name, size, comp)
end

function _m:cstr(name, size, comp)
	local str = pat2str(comp)
 	return self.stream:comp_string(name, size, str)
end

function _m:cexp(name, size, comp)
 	return self.stream:comp_expgolomb(name, size, comp)
end

function _m:lbyte(size)	
 	local val = self.stream:look_byte(size)
	-- check(self, val, "lbyte:")
	return val
end

function _m:lbit(size)	
 	local val = self.stream:look_bit(size)
	-- check(self, val, "lbit:")
	return val
end

function _m:lstr(size)	
 	local val = self.stream:look_byte_string(size)
	-- check(self, val, "lstr:")
	return val
end

function _m:lexp(size)	
 	local val = self.stream:look_expgolomb(size)
	-- check(self, val, "lbit:")
	return val
end

function _m:fbyte(char, advance, end_offset)	
	if advance == nil then advance = true end
	if end_offset == nil then end_offset = 0x7fffffff end
	return self.stream:find_byte(char, end_offset, advance)
end

function _m:fstr(pattern, advance, end_offset)
	if advance == nil then advance = true end
	if end_offset == nil then end_offset = 0x7fffffff end
	local str = pat2str(pattern)
	return self.stream:find_byte_string(str, #str, end_offset, advance)
end

function _m:rfbyte(char, advance, end_offset)	
	if advance == nil then advance = true end
	if end_offset == nil then end_offset = -0x7fffffff - 1 end
	return self.stream:rfind_byte(char, end_offset, advance)
end

function _m:rfstr(pattern, advance, end_offset)
	if advance == nil then advance = true end
	if end_offset == nil then end_offset = -0x7fffffff - 1 end
	local str = pat2str(pattern)
	return self.stream:rfind_byte_string(str, #str, end_offset, advance)
end

function _m:seek(byte, bit)
	self.stream:seekpos(byte, bit or 0)
end

function _m:seekoff(byte, bit)
    -- 暫定である、byteが0ならbitシークのみ
	return self.stream:seekoff(byte or 0, bit or 0)
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
		return transfer_to_file(self.stream, size, target, advance)
	else
		self.stream:transfer_bytes(name, size, target.stream, advance)
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
	if b == nil then
		return self.print_enabled
	end
	self.print_enabled = b
	return self.stream:enable_print(b)
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
