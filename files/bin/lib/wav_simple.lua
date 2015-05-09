-- テスト用のwavチェックコード
-- >filename="test.wav"
-- >dofile("wav.lua")

-- ライブラリロード
dofile("lib/mylib.lua")

-- ファイルオープン＆初期化
file_name = file_name or "test.wav"
stream = init_stream(file_name)
print_status()

-- ストリーム解析
B("'RIFF'",                       4)
B("file_size+muns8",              4)
B("'wave'",                       4)
B("'fmt_'",                       4)
B("size_fmt",                     4)
B("format_id",                    2)
B("num_channels",                 2)
B("sampleing_frequency",          4)
B("byte_per_sec",                 4)
B("block_size(smaple_x_channel)", 2)
B("bit_depth",                    2)
B("'data'",                       4)
B("size_audio_data",              4, data)
B("audio_data",                   reverse_32(data["size_audio_data"]))
B("tag",                          4)
B("size_data",                    4, data)
B("data",                         reverse_32(data["size_data"]))

print_status()

