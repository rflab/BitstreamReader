-- 全ストリーム共通
local gs_global = {
	main_stream  = nil,
	all_streams  = {},
	abort_offset = 0xfffffffff,
	print_offset = 0xfffffffff,
	store_lua    = false,
	store_sql    = true}	

-- 解析中のストリーム
local gs_cur_stream

-- その他グローバル
local gs_perf = profiler:new()
local gs_csv = csv:new()
local gs_progress
local gs_data = {
	skipcnt={},
	values={},
	tables={},
	bytes={},
	bits={},
	sizes={},
	streams={},
	ignore_nil=false}
	
-- 暫定
local gs_files = {}

--------------------------------------
-- 内部関数
--------------------------------------

-- データ読み込み事に記録する処理
local function on_set_value(name, byte, bit, size, value)
	-- 読込結果がエラーの場合はエラー情報をシリアライズしてabort()
	if value == false then
		print("#########################")
		print("#         ERROR         #")
		print("#########################")
		save_error_info(name, byte, bit, size, value)
		print_status()
		print("")
		assert(false)
	end

	-- get()用
	gs_data.values[name] = value

	-- Lua用もう使わないかも
	if gs_global.store_lua == true then
		if gs_data.tables[name] == nil then
			gs_data.tables[name]  = {}
			gs_data.bytes[name]   = {}
			gs_data.bits[name]    = {}
			gs_data.sizes[name]   = {}
			gs_data.streams[name] = {}
		end
		
		table.insert(gs_data.bytes[name], byte)
		table.insert(gs_data.bits[name], bit)
		table.insert(gs_data.tables[name], value)
		table.insert(gs_data.sizes[name], size)
		table.insert(gs_data.streams[name], gs_cur_stream)
	else
		local cnt = gs_data.skipcnt[name] or 0
		gs_data.skipcnt[name] = cnt + 1 
	end

	-- SQL用お試し
	if gs_global.store_sql == true then
		sql_insert_record(name, byte, bit, size, value, (gs_global.main_stream:cur()))
	end

	-- デバッグ用
	-- プリント出力開始チェック
	if gs_global.main_stream:cur() >= gs_global.print_offset then
		for i, v in ipairs(gs_global.all_streams) do
			v:enable_print(true)
		end
		print("====================================================")
		print("enable print offset="..hexstr(gs_global.print_offset))
		gs_global.main_stream:print_status()
		print("====================================================")
		gs_global.print_offset = 0xfffffffff
	end
	
	-- デバッグ用
	-- 中断チェック
	if gs_global.main_stream:cur() >= gs_global.abort_offset then
		print("")
		print("====================================================")
		print("abort point offset="..hexstr(gs_global.abort_offset))
		gs_global.main_stream:print_status()
		print("====================================================")
		assert(false)
	end
end

--------------------------------------------
-- ストリーム解析用関数
--------------------------------------------
-- ストリームを開く
-- fopenとちょっと違う
-- 'raw'はどれか一つ
-- "r" -> 読み込み
-- "w" -> 書き込み＋ファイル初期化
-- "a" -> 書き込み＋末尾追加追加
-- "+" -> リードライト
-- "b" -> バイナリモード
function open(arg1, openmode)
	openmode = openmode or "rb"
	local prev_stream = gs_cur_stream
	
	-- tbyteでファイルを開いている場合があるのでここでクローズする。
	-- 暫定処理である。
	if type(arg1)=="string" and gs_files[arg1] == true then
		close_file(arg1)
	end

	gs_cur_stream = stream:new(arg1, openmode)
	table.insert(gs_global.all_streams, gs_cur_stream) 

	-- 初回はデバッグ用メインストリームとして強制的に登録
	if gs_global.main_stream == nil then
		gs_global.main_stream = gs_cur_stream
	end

	return gs_cur_stream, prev_stream
end

-- 読み込み時エンディアン指定
-- ２バイト/４バイトの読み込みでエンディアンを変換する
function little_endian(enable)
	return gs_cur_stream:little_endian(enable)
end

-- 現在のストリームを得る
function get_stream()
	return gs_cur_stream
end

-- ストリームを入れ替える
function swap(stream)
	local prev = gs_cur_stream
	gs_cur_stream = stream
	return prev
end

-- デバッグ用設定
function set_debug(main_stream, abort_offset, print_offset)	
	gs_global.main_stream  = main_stream
	gs_global.abort_offset = abort_offset
	gs_global.print_offset = print_offset
end

-- デバッグ用設定問い合わせ
function ask_debug(main_stream)	
	main_stream = main_stream or gs_cur_stream
	main_stream:print_status()
	print("set debug? [y/n]")
	if io.read() == "y" then
		print("please enter abort_offset..")
		local abort_offset = tonumber(io.read()) or 0xfffffffff
		print("please enter print_offset..")
		local print_offset = tonumber(io.read()) or 0xfffffffff
		set_debug(main_stream, abort_offset, print_offset)
	else
		print("cancel")
	end
end

-- エラー情報を__error_info_path__に書き込む
function save_error_info(name, byte, bit, size, value)
	local error_info = {}
	error_info.file_name = __stream_path__
	error_info.byte = gs_global.main_stream:cur()
	local f = io.open(__error_info_path__, "w")
	if f == nil then
		--abort(false, "save_error_info failed")
		print("#save_error_info failed")
		return false
	end
	local s = serialize(error_info)
	print(s)
	f:write(s)
	f:close()
end

-- __error_info_path__を読み込み、デバッグを登録する
function load_error_info()
	local f = io.open(__error_info_path__, "r")
	if f == nil then 
		print("no previous error.")
		return
	end
	
	local length = f:seek("end")
	if length > 0x10000 then
		abort(false, "#too big error file")
	end 
	
	f:seek("set")
	local s = f:read("*a")
	f:close()

	local error_info = deserialize(s) or {file_name = "", byte = 0}
	if error_info.file_name ~= __stream_path__ then
		print("no previous error.")
		return
	end

	print("previous error log exists.")
	print("set debug by previous error info? [y/n/start_offset]")
	local input = io.read()
	if input == "n" then
		print("cancel")
	elseif type(tonumber(input)) == "number" then
		set_debug(
			gs_global.main_stream,
			0xffffffff,
			math.max(0, error_info.byte+tonumber(input)))
	else 
		set_debug(
			gs_global.main_stream,
			0xffffffff,
			math.max(0, error_info.byte-256))
	end

end

-- ストリーム状態表示
function print_status()
	print("<main_stream>")
	gs_global.main_stream:print_status()
	print("<current_stream>")
	if gs_global.main_stream ~= gs_cur_stream then
		gs_cur_stream:print_status()
	else
		print("  == main_stream")
	end
end

-- ストリームファイルサイズ取得
function get_size()
	return gs_cur_stream:get_size()
end

-- ストリームを最大256バイト出力
function dump(size)
	return gs_cur_stream:dump(size or 128)
end

-- 解析結果表示のON/OFF
function enable_print(b)
	if b == nil then
		return gs_cur_stream:enable_print(nil)
	else
		gs_cur_stream:enable_print(b)
	end
end

-- 解析結果表示のON/OFFに応じてprint
function sprint(...)
	return gs_cur_stream:print(...)
end

-- ファイルに出力、fpが指定されてなければただのprint
function fprint(fp, ...)
	if fp == nil then
		print(...)
	else
		fp:write(...)
	end
end

-- 現在のバイトオフセット、ビットオフセットを取得
function cur()
	return gs_cur_stream:cur()
end

-- これまでに読み込んだ値を取得する
-- なかった場合は以降無視するか中止するか選択する
function get(name)
	local val = gs_data.values[name]
	if val ~= nil then
		return val
	end

	if gs_data.ignore_nil ~= true then
		print("get nil value \""..name.."\" continue [y/n/all]")
		if io.read() == "y" then
			gs_data.values[name] = 0
			return 0
		elseif io.read() == "all" then
			gs_data.ignore_nil = true
			return 0
		else
			assert(false, "abort");
		end
	else
		print("# set 0", name)
		return 0
	end
end

-- nilが返ることをいとわない場合はこちらでget
function peek(name)
	return gs_data.values[name]
end

-- 値をセットする
function set(name, value)
	local byte, bit = cur()
	on_set_value(name, byte, bit, 0, value)
end

-- 値をセットする
-- こちらは廃止したい
function reset(name, value)
	local byte, bit = cur()
	on_set_value(name, byte, bit, 0, value)
end

-- 絶対位置シーク
function seek(byte, bit)
	return gs_cur_stream:seek(byte, bit)
end

-- 相対位置シーク
function seekoff(byte, bit)
	return gs_cur_stream:seekoff(byte, bit)
end

-- ビット単位読む
function gbit(size)
	return gs_cur_stream:gbit(size)
end

-- バイト単位読む
function gbyte(size)
	return gs_cur_stream:gbyte(size)
end

-- 文字列として読む
function gstr(size)
	return gs_cur_stream:gstr(size)
end

-- 指数ゴロムとして読む
function gexp()
	return gs_cur_stream:gexp()
end

-- ビット単位読み込み
function rbit(name, size)
	local byte, bit = cur()
	local value = gs_cur_stream:rbit(name, size)
	on_set_value(name, byte, bit, size, value)
	return value
end

-- バイト単位読み込み
function rbyte(name, size)
	local byte, bit = cur()
	local value = gs_cur_stream:rbyte(name, size)
	on_set_value(name, byte, bit, size*8, value)
	return value
end

-- 文字列として読み込み
function rstr(name, size)
	local byte, bit = cur()
	local value = gs_cur_stream:rstr(name, size)
	on_set_value(name, byte, bit, size*8, value)
	return value
end

-- 指数ゴロムとして読み込み
function rexp(name)
	local byte, bit = cur()
	local value = gs_cur_stream:rexp(name)
	on_set_value(name, byte, bit, 0, value)
	return value
end

-- ビット単位で読み込み、compとの一致を確認
function cbit(name, size, comp)
	return gs_cur_stream:cbit(name, size, comp)
end

-- バイト単位で読み込み、compとの一致を確認
function cbyte(name, size, comp)
	return gs_cur_stream:cbyte(name, size, comp)
end

-- 文字列として読み込み、compとの一致を確認
function cstr(name, size, comp)
	return gs_cur_stream:cstr(name, size, comp)
end

-- 指数ゴロムとして読み込み
function cexp(name, comp)
	return gs_cur_stream:cexp(name, comp)
end

function skip(size, begin)
	local remain = size - (cur() - begin)
	if remain ~= 0 then
		print("#skip from"..hexstr(cur()), "to="..hexstr(cur() + remain))
		rbyte("#skip data", remain)
	end
end

-- bit単位で読み込むがポインタは進めない
function lbit(size)
	return gs_cur_stream:lbit(size)
end

-- バイト単位で読み込むがポインタは進めない
function lbyte(size)
	return gs_cur_stream:lbyte(size)
end

-- 文字列を読み込むがポインタは進めない
function lstr(size)
	return gs_cur_stream:lstr(size)
end

-- バイト単位で読み込むがポインタは進めない
function lexp(size)
	return gs_cur_stream:lexp(size)
end

-- １バイト検索
function fbyte(char, advance, end_offset)
	return gs_cur_stream:fbyte(char, advance, end_offset)
end

-- 文字列を検索、もしくは"00 11 22"のようなバイナリ文字列で検索
function fstr(pattern, advance, end_offset)
	return gs_cur_stream:fstr(pattern, advance, end_offset)
end

-- １バイト逆検索
function rfbyte(char, advance, end_offset)
	return gs_cur_stream:rfbyte(char, advance, end_offset)
end

-- 文字列を検索、もしくは"00 11 22"のようなバイナリ文字列で逆検索
function rfstr(pattern, advance, end_offset)
	return gs_cur_stream:rfstr(pattern, advance, end_offset)
end

-- ストリームからファイルにデータを追記
function tbyte(name, size, target)
	if type(target) == "string" then
		gs_files[target] = gs_files[target] or true 
		return transfer_to_file(target, gs_cur_stream.stream, size, true)
	else
		return gs_cur_stream:tbyte(name, size, target, true)
	end
end

-- 文字列、もしくは"00 11 22"のようなバイナリ文字列をファイルに追記
function write(target, pattern)
	if type(target) == "string" then
		local str = pat2str(pattern)
		return write_to_file(target, str, #str)
	else
		return target:write(pattern)
	end
end

function putchar(filename, c)
	return write_to_file(filename, string.char(c), 1)
end

-- 現在位置からストリームを抜き出す
function sub_stream(name, size)
	return gs_cur_stream:sub_stream(name, size)
end

function do_until(closure, offset)
	while cur() < offset do
		closure()
	end
end

--------------------------------------
-- ストリーム解析用ユーティリティ
--------------------------------------
-- csv保存用に値を記憶
-- 引数はcbyte()等の戻り値に合わせてあるのでstore(cbyte())という書き方も可能
-- valueにはテーブル等を指定することも可
function store(key, value)
	gs_csv:insert(key, value)
end

-- store()した値をcsvに書き出す
function save_as_csv(file_name)
	return gs_csv:save(file_name)
end

--------------------------------------------
-- その他ユーティリティ
--------------------------------------------
-- 性能計測用
gs_progress = {
	prev = 10,
	check = function (self, detail)
		local cur = math.modf(cur()/get_size() * 100)
		if math.abs(self.prev - cur) >= 10 then
			self.prev = cur
			if detail == true then
				print("--------------------------")
				print(cur.."%", os.clock().."sec.\n")
				print_status()
				gs_perf:print()
				print("--------------------------")
			else
				print(cur.."%", os.clock().."sec.")
			end
		end
	end
}

function check_progress(detail)
	if detail == nil then detail = true end
	gs_progress:check(detail)
end
	

-- ファイルパスを path = dir..name..ext に分解して
-- path, dir, name, extの順に返す
function split_file_name(path)
	local dir  = string.gsub(path, "(.*/).*%..*$", "%1")
	if dir == path then dir = "" end

	local name = string.gsub(path, ".*/(.*)%..*$", "%1")
	if name == path then name = string.gsub(path, "(.*)%..*$", "%1") end

	local ext  = string.gsub(path, ".*(%..*)", "%1")
	
	return path, dir, name, ext
end

-- 最後に勝手に\nが入るprintf
function printf(format, ...)
	print(string.format(format, ...))
end

-- 16進数をHHHH(DDDD)な感じの文字列にする
function hexstr(value)
	if type(value) == "number" then
		return string.format("0x%x(%d)", value, value)
	else
		return value
	end
end

-- 16進数を1001010な感じの文字列にする
function binstr(value, size)
	-- assert(size <= 32)
	size = size or 32
	if type(value) == "number" then
		local str = ""
		for i=1, size do
			str = str..((value>>size-i)&0x1)
		end
		return str
	else
		return value
	end
end

-- 値をlengthでトリミングした文字列にする
function trimstr(v, length)
	local str = tostring(v)
	if #str > length then
		return str:sub(1, length-1).."-"		
	else
		return str
	end
end

-- 配列の中に値があればそのインデックスを返す
function find(array, value)
	assert(type(array) == "table")
	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end
	return false
end

-- テーブルをダンプする
function print_table(tbl, indent)
	indent = indent or 0
	for k, v in pairs(tbl) do
		local formatting = string.rep("  ", indent) .. k
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

-- テーブルを文字列に変換する
function serialize(o, indent_)
	local indent
	if indent_ == nil then 
		indent = "\t"
		indent_ = ""
	else
		indent = "\t"..indent_
	end
	
	local t = type(o)
	if t == "number" then
		return o
	elseif t == "string" then
		return string.format("%q", o)
	elseif t == "table" then
		local result = ""
		for k,v in pairs(o) do
			if type(k) == "number" then
				result = result..indent..serialize(v, indent)..",\n"
			else
				result = result..indent..k.." = "..serialize(v, indent)..",\n"
			end
		end
		return "{\n"..result..indent_.."}"
	else
		error("cannot serialize a " .. type(o))
	end
end

-- serializeで作った文字列をテーブルに戻す
function deserialize(d)
	--文字列を関数実行させる
	return assert(load("return " .. d .. ";"))();
	--分解すると
	--function
	--  return {x=400,y=5...};
	--end
end;

-- tbl[name].tblの末尾とtbl[name].valに値を入れる
-- 自作store関数のテーブル版
function store_to_table(tbl, name, value)
	assert(name ~= nil, "nil name specified")
	assert(value ~= nil, "nil value specified")
	
	tbl[name] = tbl[name] or {}
	tbl[name].val = value
	tbl[name].tbl = tbl[name].tbl or {}
	table.insert(tbl[name].tbl, value)
end

-- 4文字までのchar配列を数値にキャストする
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

-- 00 01 ... のような文字列パターンをchar配列に変換する
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

-- 数値をchar配列に変える
function val2str(val, size, le)
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

-- coroutine起動
function start_thread(func, ...)
	local cret, fret = coroutine.resume(coroutine.create(func), ...) 
	if cret == false then
		print(fret)
		io.write("coroutine resume failed. enter key to continue.")
		io.read()
	else
		return fret, ...
	end
end

-- SQL
-- id: byte, bit name, size, value
function sql_insert_record() assert(false, "sql is not started.") end
function sql_print() assert(false, "sql is not started.") end
function sql_commit() assert(false, "sql is not started.") end
function sql_get_value() assert(false, "sql is not started.") end
function sql_rollback() assert(false, "sql is not started.") end
function get_sql() assert(false, "sql is not started.") end
function sql_begin()
	local sql
	if __exec_dir__:match("[^ %g]") ~= nil then
		print("###################################")
		print("# can not create .db in exe dir!! #")
		print("#      create in-memory db.       #")
		print("###################################")
	 	-- sql = SQLite:new(__stream_name__..".db")
	 	sql = SQLite:new(":memory:")
	else
	 	sql = SQLite:new(__out_dir__..__stream_name__..".db")
	end	

	-------------
	-- トランザクション開始	
	-------------
	sql:exec([[begin]])
	
	-------------
	-- テーブル
	-- id, byte, bit, param_id, name, size, value
	--  |
	-- value_table[id]:id, param_id, value
	-- offset_table[id]: byte, bit
	-- param_table[param_id]: name, size
	-------------
	sql:exec([[drop table if exists param_table]])
	sql:exec([[
		create table param_table(
		param_id  integer primary key,
		name      text,
		size      integer)]])
		
	sql:exec([[drop table if exists value_table]])
	sql:exec([[
		create table value_table (
		id        integer primary key,
		param_id  integer,
		value     text)]])

	sql:exec([[drop table if exists offset_table]])
	sql:exec([[
		create table offset_table (
		id        integer primary key,
		byte      integer,
		bit       integer,
		main_byte integer)]])

	-------------
	-- VIEW
	-------------
	sql:exec([[drop view if exists bitstream]])	
	sql:exec([[
		create view bitstream as select
			v.id,
			p.name,
			o.main_byte,
			o.byte,
			o.bit,
			p.size,
			v.value
		from value_table v
		left join offset_table o on v.id = o.id
		left join param_table p on v.param_id = p.param_id]])

	-------------
	-- レコード追加クエリ
	-------------
	local insert_param_table_stmt = sql:prepare([[
		insert into param_table(param_id, name, size) values(?, ?, ?)]])
	local insert_offset_table_stmt = sql:prepare([[
		insert into offset_table(byte, bit, main_byte) values(?, ?, ?)]])
	local insert_value_table_stmt = sql:prepare([[
		insert into value_table(param_id, value) values(?, ?)]])
	local param_ids = {}
	local id = 0
	local param_id = 0
	function sql_insert_record (name, byte, bit, size, value, main_byte)
		id = id + 1
		--パラメータ
		if param_ids[name] == nil then
			param_id = param_id + 1
			param_ids[name] = param_id
			sql:reset(insert_param_table_stmt)
			sql:bind_int (insert_param_table_stmt, 1, param_id)
			sql:bind_text(insert_param_table_stmt, 2, name)
			sql:bind_int (insert_param_table_stmt, 3, size)
			sql:step(insert_param_table_stmt)
		end	
		-- offset	
		sql:reset(insert_offset_table_stmt)
		--sql:bind_int(insert_offset_table_stmt, 1, id)
		sql:bind_int(insert_offset_table_stmt, 1, byte)
		sql:bind_int(insert_offset_table_stmt, 2, bit)
		sql:bind_int(insert_offset_table_stmt, 3, main_byte)
		sql:step(insert_offset_table_stmt)
		
		-- 値
		sql:reset(insert_value_table_stmt)
		--sql:bind_int(insert_value_table_stmt, 1, id)
		sql:bind_int (insert_value_table_stmt, 1, param_ids[name])
		sql:bind_text(insert_value_table_stmt, 2, tostring(value))
		sql:step(insert_value_table_stmt)
		
		if id%100000 == 0 then
			sql:exec("commit")
			sql:exec("begin")
			print("sql_commit")
		end
	end
	
	-------------
	-- レコード取得クエリ
	-------------
	function sql_print(stmt, format, fp)
		local str={}
		local count=0
	
		-- 先頭にカラムを出力
		sql:reset(stmt)
		if format == nil then
			for i=0, sql:column_count(stmt)-1 do
				io.write(
					string.format("%-12s  ",
						tostring(sql:column_name(stmt, i)):sub(1, 12)))
			end
			fprint(fp, string.rep("------------  ", sql:column_count(stmt)))
		end
		
		-- 取得値を出力
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
				fprint(fp, string.format(string.rep("%-12s  ", sql:column_count(stmt)), table.unpack(str)))
			else
				fprint(fp, string.format(format, table.unpack(str)))
			end
		end
	end
		
	function sql_get_value(command)
		local command = [[select max(id) from bitstream]]
		local stmt = sql:prepare(command)

		if SQLITE_ROW == sql:step(stmt) then
			if sql:column_count(stmt) == 1 then
				local ty = sql:column_type(stmt, 0) 
				if ty == SQLITE_NULL then
				elseif ty == SQLITE_INTEGER then
					return sql:column_int(stmt, 0)
				elseif ty == SQLITE_TEXT then
					return sql:column_text(stmt, 0)
				else
					print("sql error:", command)
					return 0
				end
			else
				print("sql error:", command)
				return 0
			end
		else
			print("sql error:", command)
			return 0
		end
	end
	
	function sql_commit()
		sql:exec("commit");
	end

	function sql_rollback()
		sql:exec("rollback");
	end

	function get_sql()
		return sql
	end
end



function get_data()
	return gs_data
end

function get_streams()
	return gs_global.all_streams
end

