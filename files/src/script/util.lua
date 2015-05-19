--�X�g���[���ȈՃ`�F�b�N�p�֐��S

-- C����Ɠ���printf
function printf(format, ...)
	print(string.format(format, ...))
end

-- 16�i����HHHH(DDDD)�Ȋ����̕�����ɂ���
function hex2str(value)
	return string.format("0x%x(%d)", value, value)
end

-- �z��̒��ɒl������΂��̃C���f�b�N�X��Ԃ�
function array_find(array, value)
	assert(type(array) == "table")

	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end

	return false
end

-- �e�[�u�����_���v����
function print_table (tbl, indent)
	indent = indent or 0

	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			print(formatting, type(v))
			--print(formatting)
			--print_table(v, indent+1)
		else
			print(formatting .. v)
		end
	end

	-- meta = getmetatable(t)
	-- if meta ~= nil then
	-- 	print("--metatable--")
	-- 	dump_table(meta)
	-- else
	-- 	print("--no metatable--")
	-- end
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
function rbit(name, size, t)
	local val = gs_stream.stream:read_bit(name, size)
	on_read(val, "rbit:"..name)
	insert_if_table(t, name, val)
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size, t)
	local val = gs_stream.stream:read_byte(name, size)
	on_read(val, "rbyte:"..name)
	insert_if_table(t, name, val)
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size, t)
	local val = gs_stream.stream:read_string(name, size)
	on_read(val, "rstr:"..name)
	insert_if_table(t, name, val)
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp, t)
	local val = gs_stream.stream:comp_bit(name, size, comp)
	on_read(val, "cbit:"..name)
	insert_if_table(t, name, val)
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp, t)
	local val = gs_stream.stream:comp_byte(name, size, comp)
	on_read(val, "cbyte:"..name)
	insert_if_table(t, name, val)
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp, t)
	local val = gs_stream.stream:comp_string(name, size, comp)
	on_read(val, "cstr:"..name)
	insert_if_table(t, name, val)
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

-- ���̂Ƃ����w�ȍ~��ipair�̂�
function save_as_csv(file_name, tbl)
	fp = io.open(file_name, "w")
	save_as_csv_recursive(fp, transpose(normalize_table(tbl)))
end

---------------------------
-- �ȉ���util.lua�̓����֐�
---------------------------
gs_break_address = nil
gs_stream = {}

-- �X�g���[���ǂݍ��ݎ��̃G���[��\������
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

-- t�e�[�u���ł����push_back����
function insert_if_table(t, name, val)
	if t ~= nil then
		if type(t[name]) == "table" then
			table.insert(t[name], val)
		else
			t[name] = val
		end
	end
end

function save_as_csv_recursive(fp, tbl)
	save_as_csv_recursive_ipairs(fp, tbl)
	for k, v in pairs(tbl) do
		if type(k) == "string" then
			fp:write(k..", ")
			if type(v) == "table" then
				save_as_csv_recursive(fp, v)
			else
				fp:write(tostring(v).."\n")
			end
		end
	end
end
function save_as_csv_recursive_ipairs(fp, tbl)
	for i, v in ipairs(tbl) do
		if type(v) == "table" then
			save_as_csv_recursive(fp, v)
		else
			fp:write(tostring(v)..", ")
		end
	end
	fp:write("\n")
end

function normalize_table(tbl, k, dest)
	dest = dest or {}
	k = k or "root"
	normalize_table_ipairs(tbl, k, dest)
	for k, v in pairs(tbl) do
		if type(k) == "string" then
			if type(v) == "table" then
				normalize_table(v, k, dest)
			else
				dest[k] = v
			end
		end
	end
	return dest
end
function normalize_table_ipairs(tbl, k, dest)
	local t = {k}
	for i, v in ipairs(tbl) do
		if type(v) == "table" then
			normalize_table(v, "table"..i, dest)
		else
			table.insert(t, v)
		end
	end
	table.insert(dest, t)
end

-- �e�[�u���̓]�u
function transpose(tbl, ret)
	ret = ret or {}
	local colmuns = {}
	local max_row = 0
	local num_colmuns = 0
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			num_colmuns = num_colmuns + 1
			max_row = math.max(#v, max_row)
			table.insert(colmuns, v)
		end
	end
	for i=1, max_row do
		table.insert(ret, {})
		for j=1, num_colmuns do
			ret[i][j] = colmuns[j][i] or ""
		end
	end
	return ret
end
---------------------------
-- �ȉ��͖������ł��܂������Ȃ�
---------------------------
--[[
function save_as_csv(file_name, tbl, trans)
	fp = io.open(file_name, "w")
	--local nt = normalize_table(tbl)
	--
	--print("---")
	--print_table(tbl)
	--print("---")
	--print_table(nt)
	--print("---")
	--assert(false)
	--local tnt = transpose(nt)
	--save_as_csv_recursive(fp, tnt)
	save_as_csv_recursive(fp, tbl)
end
function save_as_csv_recursive(fp, tbl)
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			save_as_csv_recursive(fp, v)
		else
			if v ~= false then
				fp:write(tostring(v))
			end
			fp:write(", ")
		end
	end
	fp:write("\n")
end

--]]
