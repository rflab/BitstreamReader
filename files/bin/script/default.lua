-- テスト用のwavチェックコード
-- >filename="test.wav"
-- >dofile("wav.lua")

-- ライブラリロード
dofile("script/mylib.lua")

-- ファイルオープン＆初期化
file_name = arg1 or "test.wav"
stream = init_stream(file_name)
print_status()

dump(255)

-- ストリーム解析
local data = {}
cstr("'RIFF'",                       4, "RIFF")
byte("file_size+muns8",              4)
byte("'wave'",                       4)
byte("'fmt_'",                       4)
byte("size_fmt",                     4)
byte("format_id",                    2)
byte("num_channels",                 2)
byte("sampleing_frequency",          4)
byte("byte_per_sec",                 4)
byte("block_size(smaple_x_channel)", 2)
byte("bit_depth",                    2)
byte("'data'",                       4)
byte("size_audio_data",              4, data)

-- PCMを書き出す
write("out.pcm",                     reverse_32(data["size_audio_data"]))
byte("audio_data",                   reverse_32(data["size_audio_data"]))

byte("tag",                          4)
byte("size_data",                    4, data)
byte("data",                         reverse_32(data["size_data"]))


print_status()

