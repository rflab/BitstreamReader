-- 数値文字列解析

assert(argv[1])
stream = open_stream(argv[1])
dump()

-- 解析するなら以下のような感じ
rbyte("A", 1)
rbyte("B", 1)
rbyte("C", 1)
rbyte("D", 1)

-- 検索テスト
sbyte(0x10)
sstr("hoge")
sstr("10 11 12 13 14")

-- ファイル書き出しテスト
write("out.dat", "00 00 00 01")
wbyte("out.dat", 7)
print_status()
