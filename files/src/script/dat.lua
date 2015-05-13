-- 数値文字列解析

assert(argv[1])
stream = init_stream(argv[1])
dump(get_status().file_size)

-- 解析するなら以下のような感じ
rbyte("A", 1)
rbyte("B", 1)
rbyte("C", 1)
rbyte("D", 1)

