-- 数値文字列解析
open(__stream_path__)
dump()

-- 解析するなら以下のような感じ
rbyte("A", 1)
rbyte("B", 1)
rbyte("C", 1)
rbyte("D", 1)

-- 検索テスト
fbyte(0x10, true, 10)
fstr("hoge", true, 10)
fstr("00 01", true, 10)

-- ファイル書き出しテスト
write("out.dat", "00 00 00 01")
tbyte("dat", 7, "dat.dat")
print_status()

