-- 数値文字列解析

assert(argv[1])
stream = init_stream(argv[1])
dump(get_status().file_size)

-- 解析するなら以下のような感じ
rbyte("A", 1)
rbyte("B", 1)
rbyte("C", 1)
rbyte("D", 1)

-- 検索テスト
sbyte(0x10)
sstr("hoge")
sbstr("10 11 12 13 14")

-- ファイル書き出しテスト
write("out.dat", "00 00 00 01")
obyte("out.dat", 7)
print_status()
