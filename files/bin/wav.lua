--[[
 テスト用のwavチェックコード

 >filename="test.wav"
 >dofile("wav.lua")
--]]

print("==============================================================")
if filename == "" then
	filename = "test.wav"
end
s = BitStream.new()
s:open(filename)
local filesize = s:file_size()
print("filename:" .. filename)
print("filesize:" .. string.format("0x%08x", filesize))
print("<dump255>")
s:dump(0, 256)
print("==============================================================")

local tmp = 0

s:cB("'RIFF'",                      4, 0x52494646, true)
s:B("file_size+muns8",              4, true)
s:B("'wave'",                       4, true)
s:B("'fmt_'",                       4, true)
s:B("size_fmt",                     4, true)
s:B("format_id",                    2, true)
s:B("num_channels",                 2, true)
s:B("sampleing_frequency",          4, true)
s:B("byte_per_sec",                 4, true)
s:B("block_size(smaple_x_channel)", 2, true)
s:B("bit_depth",                    2, true)
s:B("'data'",                       4, true)

tmp = s:B("size_audio_data",        4, true)
size_audio_data = reverse32(tmp)
-- print(size_audio_data)

s:B("audio_data",                   size_audio_data, true)
s:B("tag",                          4, true)

tmp = s:B("size_data",              4, true)
size_data = reverse32(tmp)
-- print(size_data)

s:B("data",                         size_data-1, true)

if filesize ~= s:cur_byte() then
	print("# remain data: file_size=" .. filesize .. ", cur=" .. s:cur_byte()) 
end
