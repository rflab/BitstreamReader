-- C言語と同じprintf
function printf(format, ...)
	print(string.format(format, ...))
end

-- テーブルを最初の回層だけダンプする
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

-- テーブルとメタテーブルをダンプする
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

-- ストリームファイルオープン
function open_stream(file_name)
	gs_stream.status = {}
	gs_stream.status.file_name = file_name
	gs_stream.stream = Bitstream.new()
	assert(gs_stream.stream:open(file_name))
	gs_stream.status.file_size = gs_stream.stream:file_size()
	return gs_stream
end

-- ストリーム状態表示
function print_status()
	table.stream = gs_stream 
	
	printf("file_name:%s", gs_stream.status.file_name)
	printf("file_size:0x%08x", file_size())
	printf("cursor   :0x%08x(%d)", cur(), cur())
	printf("remain   :0x%08x", file_size() - cur())
end

-- ストリームファイルサイズ取得
function file_size()
	return gs_stream.stream:file_size()
end

-- ストリームを最大256バイト出力
function dump()
	gs_stream.stream:dump()
end

-- 現在のバイトオフセット、ビットオフセットを取得
function cur()
	return gs_stream.stream:cur_byte(), gs_stream.stream:cur_bit()
end

-- 解析結果表示のON/OFF
function print_on(b)
	return gs_stream.stream:enable_print(b)
end

-- ビット単位読み込み
function rbit(name, size, table)
	local val = gs_stream.stream:read_bit(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- バイト単位読み込み
function rbyte(name, size, table)
	local val = gs_stream.stream:read_byte(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- 文字列として読み込み
function rstr(name, size, table)
	local val = gs_stream.stream:read_string(name, size)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- ビット単位で読み込み、compとの一致を確認
function cbit(name, size, comp, table)
	local val = gs_stream.stream:comp_bit(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- バイト単位で読み込み、compとの一致を確認
function cbyte(name, size, comp, table)
	local val = gs_stream.stream:comp_byte(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- 文字列として読み込み、compとの一致を確認
function cstr(name, size, comp, table)
	local val = gs_stream.stream:comp_string(name, size, comp)

	if type(table) == "table" then
		table[name] = val
	end	
end

-- １バイト検索
function sbyte(char)
	gs_stream.stream:search_byte(char)
end

-- 文字列を検索、もしくは"00 11 22"のようなバイナリ文字列で検索
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

-- ストリームからファイルにデータを追記
function wbyte(filename, size)
	gs_stream.stream:copy_byte(filename, size)
end

-- 文字列、もしくは"00 11 22"のようなバイナリ文字列をファイルに追記
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