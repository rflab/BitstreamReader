-- Riffの一種だけど簡単なので得だし

little_endian(true)
cstr ("RIFF",                         4, "RIFF")
rbyte("ckSize",                       4)
cstr ("WAVE",                         4, "WAVE")
cstr ("fmt ",                         4, "fmt ")
rbyte("size",                         4)
rbyte("format",                       2)
rbyte("channels",                     2)
rbyte("samplerate",                   4)
rbyte("bytepersec",                   4)
rbyte("block_size(smaple_x_channel)", 2)
rbyte("bit_depth",                    2)

-- 残りのチャンクも見るなら
if true then
	dofile(__exec_dir__.."script/streamdef/riff.lua")
	local ed = get("ckSize") - 4 - cur() 
	while ed > cur() do
		chunk()
	end
end

print_status()
