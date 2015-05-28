-- 数値文字列解析
open(__stream_path__)
dump()

-- 解析するなら以下のような感じ
rbyte("A", 1)
rbyte("B", 1)
rbyte("C", 1)
rbyte("D", 1)

-- 検索テスト
fbyte(0x10)
fstr("hoge", true)
fstr("10 11 12 13 14", true)

-- ファイル書き出しテスト
write("out.dat", "00 00 00 01")
wbyte("out.dat", 7)
print_status()
