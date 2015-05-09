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

--簡易チェック用関数
local gs_stream = {}

function init_stream(file_name)
	gs_stream.status = {}
	gs_stream.status.file_name = file_name
	gs_stream.stream = BitStream.new()
	gs_stream.stream:open(file_name)
	gs_stream.status.file_size = gs_stream.stream:get_file_size()
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
	
	print("file_name:", gs_stream.status.file_name)
	print("file_size:", string.format("0x%08x", gs_stream.stream:get_file_size()))
	print("cursor   :", string.format("0x%08x(%d)", gs_stream.stream:cur_byte(), gs_stream.stream:cur_bit()))
end

function B(name, size, table)
	local val = gs_stream.stream:read_byte(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

function b(name, size, table)
	local val = gs_stream.stream:read_bit(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

function dump(size)
	gs_stream.stream:dump(gs_stream.stream:cur_byte(), size)
end
