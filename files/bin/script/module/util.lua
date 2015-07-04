-- ���C�u�������[�h
package.path = __exec_dir__.."script/module/?.lua"
require("profiler")
require("stream")
require("csv")

local gs_stream
local gs_all_streams = {}
local gs_progress
local gs_perf
local gs_csv
local gs_sql
local gs_data = {values={}, tables={}, bytes={}, bits={}, sizes={}, streams={}}
local gs_store_to_table = true

--------------------------------------------
-- �X�g���[����͗p�֐�
--------------------------------------------
-- �X�g���[�����J��
function open(arg1, openmode)
	openmode = openmode or "rb"
	local prev_stream = gs_stream
	gs_stream = stream:new(arg1, openmode)
	gs_csv = csv:new()
	table.insert(gs_all_streams, gs_stream) 
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

-- ��͌��ʕ\����ON/OFF�ɉ�����print
function sprint(...)
	return gs_stream:sprint(...)
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
	local val = gs_data.values[name]
	assert(val, "get nil value \""..name.."\"")
	return val
end

-- nil���Ԃ邱�Ƃ����Ƃ�Ȃ��ꍇ�͂������get
function peek(name)
	return gs_data.values[name]
end

-- �Ō�ɓǂݍ��񂾒l��j������
function reset(name, value)
	local byte, bit = cur()
	gs_stream:reset(name, value)
	on_set_value(name, byte, bit, 0, value)
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
	local byte, bit = cur()
	local value = gs_stream:rbit(name, size)
	on_set_value(name, byte, bit, size, value)
	return value
end

-- �o�C�g�P�ʓǂݍ���
function rbyte(name, size)
	local byte, bit = cur()
	local value = gs_stream:rbyte(name, size)
	on_set_value(name, byte, bit, size, value)
	return value
end

-- ������Ƃ��ēǂݍ���
function rstr(name, size)
	local byte, bit = cur()
	local value = gs_stream:rstr(name, size)
	on_set_value(name, byte, bit, size, value)
	return value
end

-- �w���S�����Ƃ��ēǂݍ���
function rexp(name)
	local byte, bit = cur()
	local value = gs_stream:rexp(name)
	on_set_value(name, byte, bit, 0, value)
	return value
end

-- �r�b�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbit(name, size, comp)
	return gs_stream:cbit(name, size, comp)
end

-- �o�C�g�P�ʂœǂݍ��݁Acomp�Ƃ̈�v���m�F
function cbyte(name, size, comp)
	return gs_stream:cbyte(name, size, comp)
end

-- ������Ƃ��ēǂݍ��݁Acomp�Ƃ̈�v���m�F
function cstr(name, size, comp)
	return gs_stream:cstr(name, size, comp)
end

-- �w���S�����Ƃ��ēǂݍ���
function cexp(name, comp)
	return gs_stream:cexp(name, comp)
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
	if string.match(pattern, "^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
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

-- �f�[�^�ǂݍ��ݎ��ɋL�^���鏈��
function on_set_value(name, byte, bit, size, value)
	if gs_data.tables[name] == nil then
		gs_data.tables[name]  = {}
		gs_data.bytes[name]   = {}
		gs_data.bits[name]    = {}
		gs_data.sizes[name]   = {}
		gs_data.streams[name] = {}
	end

	-- get()
	gs_data.values[name] = value

	-- Lua�p
	table.insert(gs_data.bytes[name], byte)
	table.insert(gs_data.bits[name], bit)
	table.insert(gs_data.tables[name], value)
	table.insert(gs_data.sizes[name], size)
	table.insert(gs_data.streams[name], gs_stream)

	-- SQL�p������
	sql_insert_record(name, byte, bit, size, value)
end

function sql_insert_record() assert(false, "sql is not started.") end
function sql_print_all() assert(false, "sql is not started.") end

function sql_begin()
	local sql
	if windows then
		sql = SQLite:new(__stream_name__..".db")
	else
		sql = SQLite:new(__stream_dir__..__stream_name__..".db")
	end

	sql:exec([[begin]]);
	sql:exec([[drop table if exists bitstream]]);
	sql:exec([[
		create table bitstream (
		id        integer primary key,
		name      text,
		byte      integer,
		bit       integer,
		size      integer,
		value     text)]]);

	-- ���R�[�h�ǉ�
	local insert_record_stmt = sql:prepare(
		[[insert into bitstream(name, byte, bit, size, value)
		 values (?, ?, ?, ?, ?);]]);
	function sql_insert_record (name, byte, bit, size, value)
		sql:reset(insert_record_stmt)
		sql:bind_text(insert_record_stmt, 1, name)
		sql:bind_int (insert_record_stmt, 2, byte)
		sql:bind_int (insert_record_stmt, 3, bit)
		sql:bind_int (insert_record_stmt, 4, size)
		sql:bind_text(insert_record_stmt, 5, tostring(value))
		sql:step(insert_record_stmt)
	end

--	-- ���R�[�h�̒l���X�V
--	local update_value_stmt = sql:prepare([[
--		update bitstream
--		set	   value = ?, size = ?
--		where  id = max(id)]])
--	function sql_update_value(value, size)
--		sql:reset(update_value_stmt)
--		sql:bind_text(update_value_stmt, 0, tostring(value))
--		sql:bind_int(update_value_stmt, 1, size)
--		sql:step(update_value_stmt)
--	end

	function sql_print(stmt, format)
		local str={}
		local count=0
	
		sql:reset(stmt)
		if format == nil then
			for i=0, sql:column_count(stmt)-1 do
				io.write(
					string.format("%-10s  ",
					tostring(sql:column_name(stmt, i)):sub(1, 10)))
			end
			print()
			printf(string.rep("----------  ", sql:column_count(stmt)))
		end
		while SQLITE_ROW == sql:step(stmt) do
			for i=0, sql:column_count(stmt)-1 do
				local ty = sql:column_type(stmt, i) 
				if ty == SQLITE_NULL then
				elseif ty == SQLITE_INTEGER then
					str[i+1] = tostring(sql:column_int(stmt, i))
				elseif ty == SQLITE_TEXT then
					str[i+1] = sql:column_text(stmt, i)
				else
					str[i+1] = "unsupported type"
				end
				
				if format == nil then
					str[i+1] = str[i+1]:sub(1, 10)
				end
			end
			if format == nil then
				printf(string.rep("%-10s  ", sql:column_count(stmt)), table.unpack(str))
			else
				printf(format, table.unpack(str))
			end
		end
	end
	
	gs_sql = sql
end

function sql_commit()
	gs_sql:exec("commit");
end

function sql_rollback()
	gs_sql:exec("rollback");
end

function get_data()
	return gs_data
end

function get_streams()
	return gs_all_streams
end

function get_sql()
	return gs_sql
end

