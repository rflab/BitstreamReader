-- wav解析
file_name = arg1 or "test.wav"
stream = init_stream(file_name)
dump(256)

local data = {}
cstr ("'RIFF'",                       4, "RIFF")
rbyte("file_size+muns8",              4)
rbyte("'wave'",                       4)
rbyte("'fmt_'",                       4)
rbyte("size_fmt",                     4)
rbyte("format_id",                    2)
rbyte("num_channels",                 2)
rbyte("sampleing_frequency",          4)
rbyte("byte_per_sec",                 4)
rbyte("block_size(smaple_x_channel)", 2)
rbyte("bit_depth",                    2)
rbyte("'data'",                       4)
rbyte("size_audio_data",              4, data)
obyte("pcm.dat",                      reverse_32(data["size_audio_data"])) -- PCMを書き出す
rbyte("tag",                          4)
rbyte("size_data",                    4, data)
rbyte("data",                         reverse_32(data["size_data"]))

print_status()

