-- 数値文字列解析

assert(argv[1])

-- 数値文字列→バイナリ文字列に変換
local str = ""
for hex in string.gmatch(argv[1], "%w+") do
	str = str .. string.char(tonumber(hex, 16))
end

-- 一旦ファイルに書き出し
local f, mes = io.open("bin.dat", "w")
f:write(str)
f:close()

-- ファイルストリームとして読み込み
stream = open_stream("bin.dat")
dump()

-- 解析するなら以下のような感じ
rbyte("A", 1)
rbyte("B", 1)
rbyte("C", 1)
rbyte("D", 1)

