--�X�g���[���ȈՃ`�F�b�N�p�֐��S

-- C����Ɠ���printf
function printf(format, ...)
	print(string.format(format, ...))
end

-- 16�i����HHHH(DDDD)�Ȋ����̕�����ɂ���
function hex2str(value)
	return string.format("0x%x(%d)", value, value)
end

-- �z��̒��ɒl������΂���
function array_find(array, value)
	assert(type(array) == "table")
	
	for i, v in ipairs(array) do
		if v == value then 
			return i
		end
	end
	
	return false
end

-- �e�[�u�����ŏ��̉�w�����_���v����
function dump_table(table)
	if table ~= nil then
		--for i, v in ipairs(table) do
		--	print("", i, v)
		--end
		for k, v in pairs(table) do
			print("", k, v)
		end
	else
		print("--talbe = nil --")
	end
end

-- �e�[�u���ƃ��^�e�[�u�����_���v����
function dump_table_all(table)
	local t = type(table)
	print("--"..t.."--")
	if t == "table" then
		dump_table(table)
	end
	
	meta = getmetatable(table)
	if meta ~= nil then
		print("--metatable--")
		dump_table(meta)
	else
		print("--no metatable--")
	end
end

-- �X�g���[���t�@�C���I�[�v��
function open_stream(file_name)
	print("open_stream("..file_name..")")
	gs_stream.status = {}
	gs_stream.status.file_name = file_name
	gs_stream.stream = Bitstream.new()
	assert(gs_stream.stream:open(file_name))
	gs_stream.status.file_size = gs_stream.stream:file_size()
	return gs_stream
end

-- �X�g���[����ԕ\��
function print_status()
	table.stream = gs_stream 
	
	printf("file_name:%s", gs_stream.status.file_name)
	printf("file_size:0x%08x", file_size())
	printf("cursor   :0x%08x(%d)", cur(), cur())
	printf("remain   :0x%08x", file_size() - cur())
end

-- �X�g���[���t�@�C���T�C�Y�擾
function file_size()
	return gs_stream.stream:file_size()
end

-- �X�g���[�����ő�256�o�C�g�o��
function dump()
	gs_stream.stream:dump()
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function cur()
	return gs_stream.stream:cur_byte(), gs_stream.stream:cur_bit()
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function seek(pos)
	return gs_stream.stream:seek(pos, 0)
end

-- ���݂̃o�C�g�I�t�Z�b�g�A�r�b�g�I�t�Z�b�g���擾
function offset_by_bit(size)
	return gs_stream.stream:offset_by_bit(size)
end

-- ��͌��ʕ\����ON/OFF
function print_on(b)
	return gs_stream.stream:enable_print(b)
end

-- �w�肵���A�h���X�O��̓ǂݍ��݌��ʂ�\�����Aassert(false)����
function set_debug_break(address)
	gs_break_address = address
end

-- �r�b�g�P�ʓǂݍ���
function rbit(name, size, table)
	local val = gs_stream.stream:read_bit(name, size)
	on_read(val, "rbit:"..name)
	
	if table ~= nil then
		table[name] = val
	end	
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size, table)
	local val = gs_stream.stream:read_byte(name, size)
	on_read(val, "rbyte:"..name)
	
	if table ~= nil then
		table[name] = val
	end	
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size, table)
	local val = gs_stream.stream:read_string(name, size)
	on_read(val, "rstr:"..name)
	
	if table ~= nil then
		table[name] = val
	end	
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp, table)
	local val = gs_stream.stream:comp_bit(name, size, comp)
	on_read(val, "cbit:"..name)
	
	if table ~= nil then
		table[name] = val
	end	
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp, table)
	local val = gs_stream.stream:comp_byte(name, size, comp)
	on_read(val, "cbyte:"..name)

	if table ~= nil then
		table[name] = val
	end	
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp, table)
	local val = gs_stream.stream:comp_string(name, size, comp)
	on_read(val, "cstr:"..name)

	if table ~= nil then
		table[name] = val
	end	
end

-- �P�o�C�g����
function sbyte(char)
	local ofs = gs_stream.stream:search_byte(char)
	on_read(ofs, "sbyte:"..char)

	return ofs
end

-- ������������A��������"00 11 22"�̂悤�ȃo�C�i��������Ō���
function sstr(pattern)
	local str = ""
	--if pattern[1] == '#' then
	if string.match(pattern, "[0-9][0-9] ") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	
	local ofs = gs_stream.stream:search_byte_string(str, #str)
	on_read(ofs, "sstr:"..pattern)
	
	return ofs
end

-- �X�g���[������t�@�C���Ƀf�[�^��ǋL
function wbyte(filename, size)
	local ret = gs_stream.stream:copy_byte(filename, size)
	on_read(ret, "wbyte:"..filename)
end

-- ������A��������"00 11 22"�̂悤�ȃo�C�i����������t�@�C���ɒǋL
function write(filename, pattern)
	local str = ""
	if string.match(pattern, "[0-9][0-9] ") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	
	local ret = gs_stream.stream:write(filename, str, #str)
	on_read(ret, "write:"..filename)
end

---------------------------
-- �ȉ���util.lua�̓����֐�
---------------------------
gs_break_address = nil
gs_stream = {}
function on_read(result, msg)
	if gs_break_address ~= nil then
		if cur() > gs_break_address - 127 then
			print_on(true)
		end
		if cur() > gs_break_address + 126 then
			assert(false)
		end
	end
	
	if result == false or result == nil then
		print_status()
		gs_stream.stream:offset_byte(-127)
		dump()
		assert(false, "assert on_read msg=".. msg)
	end
end