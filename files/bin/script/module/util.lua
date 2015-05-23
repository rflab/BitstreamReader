-- ���C�u�������[�h
package.path = "script/module/?.lua"
require("profiler")
require("stream")
require("csv")
local gs_stream
local gs_csv

--------------------------------------------
-- �G�֐��S�A
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

-- �O���[�o���ϐ���ݒ肷��
-- �Ƃ肠�����t�@�C���p�X����
function split_file_name(path)
	return
		path,
		string.gsub(path, ".*/(.*)%..*$", "%1"),
		string.gsub(path, ".*(%..*)", "%1")
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

function store_to_table(tbl, name, value)
	assert(name ~= nil, "nil name specified")
	assert(value ~= nil, "nil value specified")
	
	tbl[name] = tbl[name] or {}
	tbl[name].val = value
	tbl[name].tbl = tbl[name].tbl or {}
	table.insert(tbl[name].tbl, value)
end

--------------------------------------------
-- �X�g���[����͗p�֐��Q
--------------------------------------------
-- �X�g���[���t�@�C�����J��
function open(file_name)
	gs_stream = stream:new(file_name)
	gs_csv = csv:new()

	-- wbyte/write�̏o�͗p�t�H���_�쐬
	print("os.execute", os.execute())
	print(os.execute("mkdir out"))
	return gs_stream
end

-- �X�g���[����ԕ\��
function print_status()
	return gs_stream:print()
end

-- �X�g���[���t�@�C���T�C�Y�擾
function file_size()
	return gs_stream:size()
end

-- �X�g���[�����ő�256�o�C�g�o��
function dump()
	return gs_stream:dump()
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function cur()
	return gs_stream:cur()
end

-- ����܂łɓǂݍ��񂾒l���擾����
function get(name)
--perf:enter("get")
	local ret = gs_stream:get(name)
--perf:leave("get")
	return ret
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function seek(pos)
	return gs_stream:seek(pos)
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function offset_by_bit(size)
	return gs_stream:offset_by_bit(size)
end

-- ��͌��ʕ\����ON/OFF
function enable_print(b)
	return gs_stream:enable_print(b)
end

-- �w�肵���A�h���X�O��̓ǂݍ��݌��ʂ�\�����Aassert(false)����
function set_exit(address)
	return gs_stream:set_exit(address)
end

-- �r�b�g�P�ʓǂݍ���
function rbit(name, size)
--perf:enter("rbit")
	local val = gs_stream:rbit(name, size)
--perf:leave("rbit")
	return name, val
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size)
--perf:enter("rbyte")
	local val = gs_stream:rbyte(name, size)
--perf:leave("rbyte")
	return name, val
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size)
	return name, gs_stream:rstr(name, size)
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp)
	return name, gs_stream:cbit(name, size, comp)
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp)
	return name, gs_stream:cbyte(name, size, comp)
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp)
	return name, gs_stream:cstr(name, size, comp)
end

-- �P�o�C�g����
function sbyte(char)
	return gs_stream:sbyte(char)
end

-- ������������A��������"00 11 22"�̂悤�ȃo�C�i��������Ō���
function sstr(pattern)
	return gs_stream:sstr(pattern)
end

-- �X�g���[������t�@�C���Ƀf�[�^��ǋL
function wbyte(filename, size)
	return gs_stream:wbyte("out/"..filename, size)
end

-- ������A��������"00 11 22"�̂悤�ȃo�C�i����������t�@�C���ɒǋL
function write(filename, pattern)
	return gs_stream:write("out/"..filename, pattern)
end

-- �Q�o�C�g/�S�o�C�g�̓ǂݍ��݂ŃG���f�B�A����ϊ�����
function little_endian(enable)
	return gs_stream:little_endian(enable)
end

-- csv�ۑ��p�ɒl���L��
-- ������cbyte()���̖߂�l�ɍ��킹�Ă���̂�store(cbyte())�Ƃ������������\
-- value�ɂ̓e�[�u�������w�肷�邱�Ƃ���
function store(key, value)
--perf:enter("store")
	gs_csv:insert(key, value)
--perf:leave("store")
end

-- store()�����l��csv�ɏ����o��
function save_as_csv(file_name)
	return gs_csv:save(file_name)
end


