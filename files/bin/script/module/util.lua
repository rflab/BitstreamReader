local gs_stream
local gs_csv

--------------------------------------------
-- �X�g���[����͗p�֐�
--------------------------------------------
-- �X�g���[���t�@�C�����J��
function open(file_name)
	gs_stream = stream:new(file_name, "r")
	gs_csv = csv:new()
	return gs_stream
end

-- �X�g���[����ԕ\��
function print_status()
	return gs_stream:print()
end

function print_status_all()
	return gs_stream:print_table()
end

-- �X�g���[���t�@�C���T�C�Y�擾
function file_size()
	return gs_stream:size()
end

-- �X�g���[�����ő�256�o�C�g�o��
function dump()
	return gs_stream:dump()
end

-- ��͌��ʕ\����ON/OFF
function enable_print(b)
	return gs_stream:enable_print(b)
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
	return gs_stream:get(name)
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
	check_yield(size)
	return name, gs_stream:rbit(name, size)
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size)
	check_yield(size)
	return name, gs_stream:rbyte(name, size)
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size)
	check_yield(size)
	return name, gs_stream:rstr(name, size)
end

-- �w���S�����Ƃ��ēǂݍ���
function rexp(name)
	check_yield(size)
	return name, gs_stream:rexp(name)
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp)
	check_yield(size)
	return name, gs_stream:cbit(name, size, comp)
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp)
	check_yield(size)
	return name, gs_stream:cbyte(name, size, comp)
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp)
	check_yield(size)
	return name, gs_stream:cstr(name, size, comp)
end

-- bit�P�ʂœǂݍ��ނ��|�C���^�͐i�߂Ȃ�
function lbit(size)
	check_yield(size)
	return gs_stream:lbit(size)
end

-- �o�C�g�P�ʂœǂݍ��ނ��|�C���^�͐i�߂Ȃ�
function lbyte(size)
	check_yield(size)
	return gs_stream:lbyte(size)
end

-- �P�o�C�g����
function fbyte(char, advance)
	return gs_stream:fbyte(char, advance)
end

-- ������������A��������"00 11 22"�̂悤�ȃo�C�i��������Ō���
function fstr(pattern, advance)
	return gs_stream:fstr(pattern, advance)
end

-- �X�g���[������t�@�C���Ƀf�[�^��ǋL
function tbyte(target, size)
	check_yield(size)
	if type(target) == "string" then
		return transfer_to_file(target, gs_stream.stream, size, true)
	else
		return gs_stream:tbyte(tostring(target), target, size, true)
	end
end

-- ������A��������"00 11 22"�̂悤�ȃo�C�i����������t�@�C���ɒǋL
function write(filename, pattern)
	local str = pat2str(pattern)
	return write_to_file(filename, str, #str)
end

-- ���݈ʒu����X�g���[���𔲂��o��
function sub_stream(name, size)
	return gs_stream:sub_stream(name, size)
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
perf = profiler:new()
progress = {
	prev = 10,
	check = function (self)
		local cur = math.modf(cur()/file_size() * 100)
		if math.abs(self.prev - cur) >= 9.99 then
			self.prev = cur
			print("--------------------------")
			print(cur.."%", os.clock().."sec.\n")
			print_status()
			perf:print()
			print("--------------------------")
		end
	end
}

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
function hex2str(value)
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
function store_to_table(tbl, name, value)
	assert(name ~= nil, "nil name specified")
	assert(value ~= nil, "nil value specified")
	
	tbl[name] = tbl[name] or {}
	tbl[name].val = value
	tbl[name].tbl = tbl[name].tbl or {}
	table.insert(tbl[name].tbl, value)
end

-- 4�����܂ł̃o�b�t�@�𐔒l�ɕϊ�����
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

-- �����ɕς���
function val2str(val)
	local str = ""
	for i=1, 4 do
		str = str .. string.char((val >> (32-8*i)) & 0xff)
	end
	return str
end

-- 00 01 ... �̂悤�ȕ�����p�^�[�����o�b�t�@�ɕϊ�����
function pat2str(pattern)
	local str = ""
	if string.match(pattern, "[0-9a-f][0-9a-f]") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
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
function check_yield(size)
	if size + cur() > file_size() then
		io.write("size over. enter key to continue.")
		io.read()
		coroutine.yield()
	end
end

