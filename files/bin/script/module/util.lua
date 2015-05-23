-- ライブラリロード
package.path = "script/module/?.lua"
require("profiler")
require("stream")
require("csv")
local gs_stream
local gs_csv

--------------------------------------------
-- 雑関数郡、
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

-- グローバル変数を設定する
-- とりあえずファイルパスだけ
function split_file_name(path)
	return
		path,
		string.gsub(path, ".*/(.*)%..*$", "%1"),
		string.gsub(path, ".*(%..*)", "%1")
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

function store_to_table(tbl, name, value)
	assert(name ~= nil, "nil name specified")
	assert(value ~= nil, "nil value specified")
	
	tbl[name] = tbl[name] or {}
	tbl[name].val = value
	tbl[name].tbl = tbl[name].tbl or {}
	table.insert(tbl[name].tbl, value)
end

--------------------------------------------
-- ストリーム解析用関数群
--------------------------------------------
-- ストリームファイルを開く
function open(file_name)
	gs_stream = stream:new(file_name)
	gs_csv = csv:new()

	-- wbyte/writeの出力用フォルダ作成
	print("os.execute", os.execute())
	print(os.execute("mkdir out"))
	return gs_stream
end

-- ストリーム状態表示
function print_status()
	return gs_stream:print()
end

-- ストリームファイルサイズ取得
function file_size()
	return gs_stream:size()
end

-- ストリームを最大256バイト出力
function dump()
	return gs_stream:dump()
end

-- 現在のバイトオフセット、ビットオフセットを取得
function cur()
	return gs_stream:cur()
end

-- これまでに読み込んだ値を取得する
function get(name)
--perf:enter("get")
	local ret = gs_stream:get(name)
--perf:leave("get")
	return ret
end

-- 現在のバイトオフセット、ビットオフセットを取得
function seek(pos)
	return gs_stream:seek(pos)
end

-- 現在のバイトオフセット、ビットオフセットを取得
function offset_by_bit(size)
	return gs_stream:offset_by_bit(size)
end

-- 解析結果表示のON/OFF
function enable_print(b)
	return gs_stream:enable_print(b)
end

-- 指定したアドレス前後の読み込み結果を表示し、assert(false)する
function set_exit(address)
	return gs_stream:set_exit(address)
end

-- ビット単位読み込み
function rbit(name, size)
--perf:enter("rbit")
	local val = gs_stream:rbit(name, size)
--perf:leave("rbit")
	return name, val
end

-- バイト単位読み込み
function rbyte(name, size)
--perf:enter("rbyte")
	local val = gs_stream:rbyte(name, size)
--perf:leave("rbyte")
	return name, val
end

-- 文字列として読み込み
function rstr(name, size)
	return name, gs_stream:rstr(name, size)
end

-- ビット単位で読み込み、compとの一致を確認
function cbit(name, size, comp)
	return name, gs_stream:cbit(name, size, comp)
end

-- バイト単位で読み込み、compとの一致を確認
function cbyte(name, size, comp)
	return name, gs_stream:cbyte(name, size, comp)
end

-- 文字列として読み込み、compとの一致を確認
function cstr(name, size, comp)
	return name, gs_stream:cstr(name, size, comp)
end

-- １バイト検索
function sbyte(char)
	return gs_stream:sbyte(char)
end

-- 文字列を検索、もしくは"00 11 22"のようなバイナリ文字列で検索
function sstr(pattern)
	return gs_stream:sstr(pattern)
end

-- ストリームからファイルにデータを追記
function wbyte(filename, size)
	return gs_stream:wbyte("out/"..filename, size)
end

-- 文字列、もしくは"00 11 22"のようなバイナリ文字列をファイルに追記
function write(filename, pattern)
	return gs_stream:write("out/"..filename, pattern)
end

-- ２バイト/４バイトの読み込みでエンディアンを変換する
function little_endian(enable)
	return gs_stream:little_endian(enable)
end

-- csv保存用に値を記憶
-- 引数はcbyte()等の戻り値に合わせてあるのでstore(cbyte())という書き方も可能
-- valueにはテーブル等を指定することも可
function store(key, value)
--perf:enter("store")
	gs_csv:insert(key, value)
--perf:leave("store")
end

-- store()した値をcsvに書き出す
function save_as_csv(file_name)
	return gs_csv:save(file_name)
end


