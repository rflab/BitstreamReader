function printf(format, ...)
	print(string.format(format, ...))
end

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

--ストリーム簡易チェック用関数
local gs_stream = {}

function init_stream(file_name)
	gs_stream.status = {}
	gs_stream.status.file_name = file_name
	gs_stream.stream = Bitstream.new()
	gs_stream.stream:open(file_name)
	gs_stream.status.file_size = gs_stream.stream:file_size()
	return gs_stream
end

function get_status()
	table = {}
	table.stream    = gs_stream.stream 
	table.file_size = gs_stream.status.file_size
	table.file_name = gs_stream.status.file_name
	table.cur_bit   = gs_stream.stream:cur_bit()
	table.cur_byte  = gs_stream.stream:cur_byte()
	return table
end

function print_status()
	table.stream = gs_stream 
	
	printf("file_name:%s", gs_stream.status.file_name)
	printf("file_size:0x%08x", gs_stream.stream:file_size())
	printf("cursor   :0x%08x(%d)", gs_stream.stream:cur_byte(), gs_stream.stream:cur_bit())
	printf("remain   :0x%08x", gs_stream.stream:file_size()-gs_stream.stream:cur_byte())
end

function rbit(name, size, table)
	local val = gs_stream.stream:read_bit(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

function rbyte(name, size, table)
	local val = gs_stream.stream:read_byte(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

function rstr(name, size, table)
	local val = gs_stream.stream:read_string(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

function cbit(name, size, comp, table)
	local val = gs_stream.stream:comp_bit(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

function cbyte(name, size, comp, table)
	local val = gs_stream.stream:comp_byte(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

function cstr(name, size, comp, table)
	local val = gs_stream.stream:comp_string(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

function sbyte(char)
	gs_stream.stream:search_byte(char)
end

function sstr(str)
	gs_stream.stream:search_byte_string(str, #str)
end

-- "00 01 02 .."の文字列からバイト列を検索
function sbstr(bstr)
	local str = ""
	for hex in string.gmatch(bstr, "%w+") do
		str = str .. string.char(tonumber(hex, 16))
	end
	gs_stream.stream:search_byte_string(str, #str)
end

function dump(size)
	gs_stream.stream:dump(size)
end

function obyte(filename, size)
	gs_stream.stream:out_byte(filename, size)
end

function write(filename, bstr)
	local str = ""
	if string.match(bstr, "[0-9][0-9] ") ~= nil then
		for hex in string.gmatch(bstr, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = bstr
	end
	gs_stream.stream:write(filename, str, #str)
end
