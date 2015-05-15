-- C����Ɠ���printf
function printf(format, ...)
	print(string.format(format, ...))
end

-- �e�[�u�����ŏ��̉�w�����_���v����
function dump_table(table)
	if table ~= nil then
		for i, v in ipairs(table) do
			print("", i, v)
		end
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

--�X�g���[���ȈՃ`�F�b�N�p�֐�
local gs_stream = {}

-- �X�g���[���t�@�C���I�[�v��
function open_stream(file_name)
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

-- ��͌��ʕ\����ON/OFF
function print_on(b)
	return gs_stream.stream:enable_print(b)
end

-- �r�b�g�P�ʓǂݍ���
function rbit(name, size, table)
	local val = gs_stream.stream:read_bit(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size, table)
	local val = gs_stream.stream:read_byte(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size, table)
	local val = gs_stream.stream:read_string(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp, table)
	local val = gs_stream.stream:comp_bit(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp, table)
	local val = gs_stream.stream:comp_byte(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp, table)
	local val = gs_stream.stream:comp_string(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- �P�o�C�g����
function sbyte(char)
	gs_stream.stream:search_byte(char)
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
	gs_stream.stream:search_byte_string(str, #str)
end

-- �X�g���[������t�@�C���Ƀf�[�^��ǋL
function wbyte(filename, size)
	gs_stream.stream:copy_byte(filename, size)
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
	gs_stream.stream:write(filename, str, #str)
end