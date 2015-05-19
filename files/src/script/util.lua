--ストリーム簡易チェック用関数郡

-- C言語と同じprintf
function printf(format, ...)
	print(string.format(format, ...))
end

-- 16進数をHHHH(DDDD)な感じの文字列にする
function hex2str(value)
	return string.format("0x%x(%d)", value, value)
end

-- 配列の中に値があればそのインデックスを返す
function array_find(array, value)
	assert(type(array) == "table")

	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end

	return false
end

-- テーブルをダンプする
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

-- ストリームファイルオープン
function open_stream(file_name)
	print("open_stream("..file_name..")")
	gs_stream.status = {}
	gs_stream.status.file_name = file_name
	gs_stream.stream = Bitstream.new()
	assert(gs_stream.stream:open(file_name))
	gs_stream.status.file_size = gs_stream.stream:file_size()
	return gs_stream
end

-- ストリーム状態表示
function print_status()
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

-- 現在のバイトオフセット、ビットオフセットを取得
function seek(pos)
	return gs_stream.stream:seek(pos, 0)
end

-- 現在のバイトオフセット、ビットオフセットを取得
function offset_by_bit(size)
	return gs_stream.stream:offset_by_bit(size)
end

-- 解析結果表示のON/OFF
function print_on(b)
	return gs_stream.stream:enable_print(b)
end

-- 指定したアドレス前後の読み込み結果を表示し、assert(false)する
function set_debug_break(address)
	gs_break_address = address
end


-- ビット単位読み込み
function rbit(name, size, t)
	local val = gs_stream.stream:read_bit(name, size)
	on_read(val, "rbit:"..name)
	insert_if_table(t, name, val)
end

-- バイト単位読み込み
function rbyte(name, size, t)
	local val = gs_stream.stream:read_byte(name, size)
	on_read(val, "rbyte:"..name)
	insert_if_table(t, name, val)
end

-- 文字列として読み込み
function rstr(name, size, t)
	local val = gs_stream.stream:read_string(name, size)
	on_read(val, "rstr:"..name)
	insert_if_table(t, name, val)
end

-- ビット単位で読み込み、compとの一致を確認
function cbit(name, size, comp, t)
	local val = gs_stream.stream:comp_bit(name, size, comp)
	on_read(val, "cbit:"..name)
	insert_if_table(t, name, val)
end

-- バイト単位で読み込み、compとの一致を確認
function cbyte(name, size, comp, t)
	local val = gs_stream.stream:comp_byte(name, size, comp)
	on_read(val, "cbyte:"..name)
	insert_if_table(t, name, val)
end

-- 文字列として読み込み、compとの一致を確認
function cstr(name, size, comp, t)
	local val = gs_stream.stream:comp_string(name, size, comp)
	on_read(val, "cstr:"..name)
	insert_if_table(t, name, val)
end

-- １バイト検索
function sbyte(char)
	local ofs = gs_stream.stream:search_byte(char)
	on_read(ofs, "sbyte:"..char)
	return ofs
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

	local ofs = gs_stream.stream:search_byte_string(str, #str)
	on_read(ofs, "sstr:"..pattern)

	return ofs
end

-- ストリームからファイルにデータを追記
function wbyte(filename, size)
	local ret = gs_stream.stream:copy_byte(filename, size)
	on_read(ret, "wbyte:"..filename)
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

	local ret = gs_stream.stream:write(filename, str, #str)
	on_read(ret, "write:"..filename)
end

-- 今のところ二層以降はipairのみ
function save_as_csv(file_name, tbl)
	fp = io.open(file_name, "w")
	save_as_csv_recursive(fp, transpose(normalize_table(tbl)))
end

---------------------------
-- 以下はutil.luaの内部関数
---------------------------
gs_break_address = nil
gs_stream = {}

-- ストリーム読み込み時のエラーを表示する
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

-- tテーブルであればpush_backする
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

-- テーブルの転置
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
-- 以下は未実装でうまく動かない
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
