local name = ...           -- �����������W���[����
local _m = {}              -- �����o�֐������Ђ���e�[�u��
local _meta = {__index=_m} 
local _v = {}              -- �v���C�x�[�g�ϐ�(self���L�[�Ƃ���e�[�u��)
package.loaded[name] = _m  -- ��x�ڂ�require()�͂��ꂪ�Ԃ����
_G[name] = _m              -- �O���[�o���ɓo�^���Ă���

local perf = profiler:new() -- ���\�v��

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

function _m:new(file_name)
	obj = {tbl={}}
	--_v[obj] = {}
	setmetatable(obj, _meta )

	if file_name then
		print("open stream ("..file_name..")")
		obj.stream = FileBitstream.new()
		obj.file_name = file_name
		assert(obj.stream:open(file_name, "r"))
	else
		print("create stream ()")
		obj.stream = Bitstream.new()
	end

	obj.stream:little_endian(false)
	obj.is_little_endian = false
	return obj
end

function _m:print()	
	printf("name    : %s", self.file_name)
	printf("size    : 0x%08x", self:size())
	printf("cursor  : 0x%08x(%d)", self:cur(), self:cur())
	printf("remain  : 0x%08x", self:size() - self:cur())
	perf:print()
end

function _m:print_table()	
	print_table(self.tbl)
end

function _m:size()	
	return self.stream:size()
end

function _m:dump()	
	self.stream:dump(256)
end

function _m:cur()	
	return self.stream:byte_pos(), self.stream:bit_pos()
end

function _m:get(name)	
	return self.tbl[name]
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
	check(self, val, "rbyte:"..name)
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

function _m:fbyte(char, advance)	
	local ofs = self.stream:find_byte(char, advance)
	check(self, ofs, "fbyte:"..char)
	return ofs
end

function _m:fstr(pattern, advance)
	local str = pat2str(pattern)
	local ofs = self.stream:find_byte_string(str, #str, advance)
	check(self, ofs, "sstr:"..pattern)
	return ofs	
end

function _m:seek(byte, bit)
	self.stream:seekpos(byte, bit or 0)
end

function _m:seekoff(byte, bit)
	self.stream:seekoff_byte(byte)
	self.stream:seekoff_bit(bit)
end

--function _m:write(filename, pattern)
--	local str = ""
--	if string.match(pattern, "[0-9][0-9] ") ~= nil then
--		for hex in string.gmatch(pattern, "%w+") do
--			str = str .. string.char(tonumber(hex, 16))
--		end
--	else
--		str = pattern
--	end
--	local ret = self.stream:output_to_file(filename, str, #str)
--	check(self, ret, "write:"..filename)
--end

function _m:enable_print(b)	
	return self.stream:enable_print(b)
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

function _m:sub_stream(name, size)	
	local b = Bitstream:new()
	print(size)
	self.stream:sub_stream(name, b, size, false)
	return b
end

--function progress()
--	local p = math.modf(cur()/file_size() * 100)
--	if math.modf(p % 10) == 0 and progress <= p then
--		gs_prev_progress = gs_prev_progress + 10
--		print(progress.."%", os.clock().."sec.")
--		profiler:print()
--	end
--end

