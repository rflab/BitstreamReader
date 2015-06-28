-- ���C�u�������[�h
package.path = __exec_dir__.."script/module/?.lua"
require("profiler")
require("stream")
require("csv")

local gs_stream
local gs_progress
local gs_perf
local gs_csv
local gs_vals = {}
local gs_tbls = {}
local gs_store_to_table = true

--------------------------------------------
-- �X�g���[����͗p�֐�
--------------------------------------------
-- �X�g���[���t�@�C�����J��
function open(arg1, openmode)
	openmode = openmode or "rb"
	local prev_stream = gs_stream
	gs_stream = stream:new(arg1, openmode)
	gs_csv = csv:new()
	return gs_stream, prev_stream
end

-- �X�g���[�������ւ���
function swap(stream)
	local prev = gs_stream
	gs_stream = stream
	return prev
end

-- �X�g���[����ԕ\��
function print_status()
	return gs_stream:print()
end

-- �S���\��
function print_status_all()
	return gs_stream:print_table()
end

-- �X�g���[���t�@�C���T�C�Y�擾
function get_size()
	return gs_stream:get_size()
end

-- �X�g���[�����ő�256�o�C�g�o��
function dump(size)
	return gs_stream:dump(size or 128)
end

-- ��͌��ʕ\����ON/OFF
function enable_print(b)
	return gs_stream:enable_print(b)
end

-- ��͌��ʕ\����ON/OFF
function enable_store_all(b)
	gs_store_to_table = b
end

-- ��͌��ʕ\����ON/OFF��₢���킹��
function ask_enable_print()
	return gs_stream:ask_enable_print()
end

-- �Q�o�C�g/�S�o�C�g�̓ǂݍ��݂ŃG���f�B�A����ϊ�����
function little_endian(enable)
	return gs_stream:little_endian(enable)
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function cur()
	return gs_stream:cur()
end

-- ����܂łɓǂݍ��񂾒l���擾����
function get(name)
	--local value = gs_stream:get(name)
	--return value or gs_vals[name]
	local val = gs_vals[name]
	assert(val, "get nil value \""..name.."\"")
	return val
end

-- nil���Ԃ邱�Ƃ����Ƃ�Ȃ��ꍇ�͂������get
function peek(name)
	return gs_vals[name]
end

-- �Ō�ɓǂݍ��񂾒l��j������
function reset(name, value)
	gs_stream:reset(name, value)
	gs_vals[name] = value
	gs_tbls[name] = {value}
end

-- ��Έʒu�V�[�N
function seek(byte, bit)
	return gs_stream:seek(byte, bit)
end

-- ���Έʒu�V�[�N
function seekoff(byte, bit)
	return gs_stream:seekoff(byte, bit)
end

-- �w�肵���A�h���X�O��̓ǂݍ��݌��ʂ�\�����Aassert(false)����
function set_exit(address)
	return gs_stream:set_exit(address)
end

-- �r�b�g�P�ʓǂݍ���
function rbit(name, size)
	local value = gs_stream:rbit(name, size)
	on_read_value(name, value)
	return value
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size)
	local value = gs_stream:rbyte(name, size)
	on_read_value(name, value)
	return value
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size)
	local value = gs_stream:rstr(name, size)
	on_read_value(name, value)
	return value
end

-- �w���S�����Ƃ��ēǂݍ���
function rexp(name)
	local value = gs_stream:rexp(name)
	on_read_value(name, value)
	return value
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp)
	local value = gs_stream:cbit(name, size, comp)
	on_read_value(name, value)
	return value
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp)
	local value = gs_stream:cbyte(name, size, comp)
	on_read_value(name, value)
	return value
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp)
	local value = gs_stream:cstr(name, size, comp)
	on_read_value(name, value)
	return value
end

-- �w���S�����Ƃ��ēǂݍ���
function cexp(name)
	local value = gs_stream:cexp(name)
	on_read_value(name, value)
	return value
end

-- bit�P�ʂœǂݍ��ނ��|�C���^�͐i�߂Ȃ�
function lbit(size)
	return gs_stream:lbit(size)
end

-- �o�C�g�P�ʂœǂݍ��ނ��|�C���^�͐i�߂Ȃ�
function lbyte(size)
	return gs_stream:lbyte(size)
end

-- �o�C�g�P�ʂœǂݍ��ނ��|�C���^�͐i�߂Ȃ�
function lexp(size)
	return gs_stream:lexp(size)
end

-- �P�o�C�g����
function fbyte(char, advance, end_offset)
	return gs_stream:fbyte(char, advance, end_offset)
end

-- ������������A��������"00 11 22"�̂悤�ȃo�C�i��������Ō���
function fstr(pattern, advance, end_offset)
	return gs_stream:fstr(pattern, advance, end_offset)
end

-- �X�g���[������t�@�C���Ƀf�[�^��ǋL
function tbyte(name, size, target)
	if type(target) == "string" then
		return transfer_to_file(target, gs_stream.stream, size, true)
	else
		return gs_stream:tbyte(name, size, target, true)
	end
end

-- ������A��������"00 11 22"�̂悤�ȃo�C�i����������t�@�C���ɒǋL
function write(filename, pattern)
	local str = pat2str(pattern)
	return write_to_file(filename, str, #str)
end

function putchar(filename, char)
	return write_to_file(filename, tostring(cahr), 1)
end

-- ���݈ʒu����X�g���[���𔲂��o��
function sub_stream(name, size)
	return gs_stream:sub_stream(name, size)
end

function do_until(closure, offset)
	while cur() < offset do
		closure()
	end
end

--------------------------------------
-- �X�g���[����͗p���[�e�B���e�B
--------------------------------------
-- csv�ۑ��p�ɒl���L��
-- ������cbyte()���̖߂�l�ɍ��킹�Ă���̂�store(cbyte())�Ƃ������������\
-- value�ɂ̓e�[�u�������w�肷�邱�Ƃ���
function store(key, value)
	gs_csv:insert(key, value)
end

-- store()�����l��csv�ɏ����o��
function save_as_csv(file_name)
	return gs_csv:save(file_name)
end

--------------------------------------------
-- ���̑����[�e�B���e�B
--------------------------------------------
-- ���\�v���p
gs_perf = profiler:new()
gs_progress = {
	prev = 10,
	check = function (self)
		local cur = math.modf(cur()/get_size() * 100)
		if math.abs(self.prev - cur) >= 9.99 then
			self.prev = cur
			print("--------------------------")
			print(cur.."%", os.clock().."sec.\n")
			print_status()
			gs_perf:print()
			print("--------------------------")
		end
	end
}

function check_progress()
	gs_progress:check()
end
	

-- �t�@�C���p�X�� path = dir..name..ext �ɕ�������
-- path, dir, name, ext�̏��ɕԂ�
function split_file_name(path)
	local dir  = string.gsub(path, "(.*/).*%..*$", "%1")
	if dir == path then dir = "" end

	local name = string.gsub(path, ".*/(.*)%..*$", "%1")
	if name == path then name = string.gsub(path, "(.*)%..*$", "%1") end

	local ext  = string.gsub(path, ".*(%..*)", "%1")
	
	return path, dir, name, ext
end

-- �Ō�ɏ����\n������printf
function printf(format, ...)
	print(string.format(format, ...))
end

-- 16�i����HHHH(DDDD)�Ȋ����̕�����ɂ���
function hexstr(value)
	return string.format("0x%x(%d)", value, value)
end

-- �z��̒��ɒl������΂��̃C���f�b�N�X��Ԃ�
function find(array, value)
	assert(type(array) == "table")
	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end
	return false
end

-- �e�[�u�����_���v����
function print_table(tbl, indent)
	indent = indent or 0
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent) .. k
		if type(v) == "table" then
			print(formatting)
			print_table(v, indent+1)
		else
			print(formatting, v)
		end
	end
	local meta = getmetatable(tbl)
	if meta ~= nil then
		print_table(meta, indent+1)
	end
end

-- tbl[name].tbl�̖�����tbl[name].val�ɒl������
-- ����store�֐��̃e�[�u����
function store_to_table(tbl, name, value)
	assert(name ~= nil, "nil name specified")
	assert(value ~= nil, "nil value specified")
	
	tbl[name] = tbl[name] or {}
	tbl[name].val = value
	tbl[name].tbl = tbl[name].tbl or {}
	table.insert(tbl[name].tbl, value)
end

-- 4�����܂ł�char�z��𐔒l�ɃL���X�g����
function str2val(buf_str, little_endian)
	local s
	local val = 0
	local len = #buf_str
	if little_endian then	
		assert(len==4 or len==2, "length str:"..str)
		s = buf_str:reverse()
	else
		s = buf_str
	end
	
	for i=1, len do
		val = val << 8 | s:byte(i)
	end
	return val
end

-- 00 01 ... �̂悤�ȕ�����p�^�[����char�z��ɕϊ�����
function pat2str(pattern)
	local str = ""
	if string.match(pattern, "^[0-9a-f][0-9a-f]") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	return str
end

-- ���l��char�z��ɕς���
function hex2str(val, size, le)
	size = size or 4
	assert(size <= 4)
	local str = ""
	
	if le == nil or le == false then
		for i=0, size-1 do
			str = string.char((val >> (8*i)) & 0xff) .. str
		end
	else
		for i=0, size-1 do
			str = str .. string.char((val >> (8*i)) & 0xff)
		end
	end
	return str
end

-- coroutine�N��
function start_thread(func, ...)
	cret, fret = coroutine.resume(coroutine.create(func), ...) 
	if cret == false then
		print(fret)
		io.write("coroutine resume failed. enter key to continue.")
		io.read()
	else
		return fret, ...
	end
end

--------------------------------------
-- �����֐��A�ʏ�g��Ȃ�
--------------------------------------
function check(size)
	if size + cur() > get_size() then
		print("size over", "size:", get_size(), "readsize:", size)
		io.write("size over. enter key to continue.")
		io.read()
		--coroutine.yield()
	end
end


-- �e�[�u�����擾
function get_tbl()
	return gs_vals, gs_tbls
end

-- �f�[�^�ǂݍ��ݎ��ɋL�^���鏈��
function on_read_value(key, value)
	gs_vals[key] = value
	gs_tbls[key] = gs_tbls[key] or {}
	table.insert(gs_tbls[key], value)
end
