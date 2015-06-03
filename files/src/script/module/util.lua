local gs_stream
local gs_csv

--------------------------------------------
-- ストリーム解析用関数
--------------------------------------------
-- ストリームファイルを開く
function open(file_name)
	gs_stream = stream:new(file_name, "r")
	gs_csv = csv:new()
	return gs_stream
end

-- ストリーム状態表示
function print_status()
	return gs_stream:print()
end

function print_status_all()
	return gs_stream:print_table()
end

-- ストリームファイルサイズ取得
function file_size()
	return gs_stream:size()
end

-- ストリームを最大256バイト出力
function dump()
	return gs_stream:dump()
end

-- 解析結果表示のON/OFF
function enable_print(b)
	return gs_stream:enable_print(b)
end

-- ２バイト/４バイトの読み込みでエンディアンを変換する
function little_endian(enable)
	return gs_stream:little_endian(enable)
end

-- 現在のバイトオフセット、ビットオフセットを取得
function cur()
	return gs_stream:cur()
end

-- これまでに読み込んだ値を取得する
function get(name)
	return gs_stream:get(name)
end

-- 絶対位置シーク
function seek(byte, bit)
	return gs_stream:seek(byte, bit)
end

-- 相対位置シーク
function seekoff(byte, bit)
	return gs_stream:seekoff(byte, bit)
end

-- 指定したアドレス前後の読み込み結果を表示し、assert(false)する
function set_exit(address)
	return gs_stream:set_exit(address)
end

-- ビット単位読み込み
function rbit(name, size)
	check_yield(size)
	return name, gs_stream:rbit(name, size)
end

-- バイト単位読み込み
function rbyte(name, size)
	check_yield(size)
	return name, gs_stream:rbyte(name, size)
end

-- 文字列として読み込み
function rstr(name, size)
	check_yield(size)
	return name, gs_stream:rstr(name, size)
end

-- 指数ゴロムとして読み込み
function rexp(name)
	check_yield(size)
	return name, gs_stream:rexp(name)
end

-- ビット単位で読み込み、compとの一致を確認
function cbit(name, size, comp)
	check_yield(size)
	return name, gs_stream:cbit(name, size, comp)
end

-- バイト単位で読み込み、compとの一致を確認
function cbyte(name, size, comp)
	check_yield(size)
	return name, gs_stream:cbyte(name, size, comp)
end

-- 文字列として読み込み、compとの一致を確認
function cstr(name, size, comp)
	check_yield(size)
	return name, gs_stream:cstr(name, size, comp)
end

-- bit単位で読み込むがポインタは進めない
function lbit(size)
	check_yield(size)
	return gs_stream:lbit(size)
end

-- バイト単位で読み込むがポインタは進めない
function lbyte(size)
	check_yield(size)
	return gs_stream:lbyte(size)
end

-- １バイト検索
function fbyte(char, advance)
	return gs_stream:fbyte(char, advance)
end

-- 文字列を検索、もしくは"00 11 22"のようなバイナリ文字列で検索
function fstr(pattern, advance)
	return gs_stream:fstr(pattern, advance)
end

-- ストリームからファイルにデータを追記
function tbyte(target, size)
	check_yield(size)
	if type(target) == "string" then
		return transfer_to_file(target, gs_stream.stream, size, true)
	else
		return gs_stream:tbyte(tostring(target), target, size, true)
	end
end

-- 文字列、もしくは"00 11 22"のようなバイナリ文字列をファイルに追記
function write(filename, pattern)
	local str = pat2str(pattern)
	return write_to_file(filename, str, #str)
end

-- 現在位置からストリームを抜き出す
function sub_stream(name, size)
	return gs_stream:sub_stream(name, size)
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
function hex2str(value)
	return string.format("0x%x(%d)", value, value)
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

-- tbl[name].tblの末尾とtbl[name].valに値を入れる
function store_to_table(tbl, name, value)
	assert(name ~= nil, "nil name specified")
	assert(value ~= nil, "nil value specified")
	
	tbl[name] = tbl[name] or {}
	tbl[name].val = value
	tbl[name].tbl = tbl[name].tbl or {}
	table.insert(tbl[name].tbl, value)
end

-- 4文字までのバッファを数値に変換する
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

-- 数字に変える
function val2str(val)
	local str = ""
	for i=1, 4 do
		str = str .. string.char((val >> (32-8*i)) & 0xff)
	end
	return str
end

-- 00 01 ... のような文字列パターンをバッファに変換する
function pat2str(pattern)
	local str = ""
	if string.match(pattern, "[0-9a-f][0-9a-f]") ~= nil then
		for hex in string.gmatch(pattern, "%w+") do
			str = str .. string.char(tonumber(hex, 16))
		end
	else
		str = pattern
	end
	return str
end

-- coroutine起動
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
-- 内部関数、通常使わない
--------------------------------------
function check_yield(size)
	if size + cur() > file_size() then
		io.write("size over. enter key to continue.")
		io.read()
		coroutine.yield()
	end
end

