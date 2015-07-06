-- riff解析
function riff()
	little_endian(true)

	local id   = cstr ("ckID",   4, "RIFF")
	local size = rbyte("ckSize", 4)
	local form = rstr ("ckData", 4)
	
	local ed = cur() + get("ckSize") - 4
	while ed > cur() do
		chunk()
	end
end

function chunk()
	local id   = rstr ("ckID",   4)
	local size = rbyte("ckSize", 4)
	if specific_chunk(id, size) == false then
		rbyte("ckData", size)
	end
end

function specific_chunk(id, size)
	if id == "LIST" then
		rstr("list_type", 4)
		if get("list_type") == "movi" then
			movi_list_chunk(size-4)
		else
			list_chunk(size-4)
		end
	elseif id == "idx1" then
		idx1_chunk(size)
	elseif id == "WAVE" then
		wave_chunk()
--	elseif id == "" then
--	elseif id == "" then
--	elseif id == "" then
--	elseif id == "" then
--	elseif id == "" then
	else
		return false
	end
	return true
end	

function list_chunk(size)
	local ed = cur() + size
	repeat
		chunk()
	until cur() >= ed
end

function movi_list_chunk(size)
	enable_print(false)
	
	local video_count = 0
	local audio_count = 0
	local ed = cur() + size
	while cur() < ed do
		rstr("stream_type", 4)
		rbyte("frame_size", 4)
		rbyte("data", get("frame_size") + (get("frame_size") & 1))
		io.write("-")
	end
end

function idx1_chunk(size)
	local ed = cur() + size
	while cur() < ed do
		rstr ("dwChunkId", 4)
		rbyte("dwFlags",   4)
		rbyte("dwOffset",  4)
		rbyte("dwSize",    4)
		io.write("|")
	end
end

function wave_chunk()
	cstr ("fmt ",                               4, "fmt ")
	rbyte("size",                               4)
	rbyte("format",                             2)
	rbyte("channels",                           2)
	rbyte("samplerate",                         4)
	rbyte("bytepersec",                         4)
	rbyte("block_size(smaple_x_channel)",       2)
	rbyte("bit_depth",                          2)
	chunk()
end

if __stream_type__ == ".riff" then
	riff()
end



