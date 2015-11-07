-- aac解析
-- ストリーム解析

function aac_frame(size)
	local begin = cur()

	io.write("  `--start audio frame - ")

	rbit("sync", 12)
	rbit("id", 1)
	rbit("layer", 2)
	rbit("protection", 1)
	
	rbit("profile", 2)
	rbit("sampling_freq", 4)
	rbit("private_Bit", 1)
	rbit("channel", 3)
	rbit("original_cpy", 1)
	rbit("home", 1)
	rbit("copyright1", 1)
	rbit("copyright2", 1)
	rbit("aac_frame_lenght", 13)
	rbit("adts_buffer_fullness", 11)
	rbit("no_low_data_blocks_in_frame", 2)
	rbyte("payload", get("aac_frame_lenght")-7)
	
	io.write("frame_size=".. hexstr(get("aac_frame_lenght")))
	
	if cur() ~= begin+size then
		print("######size error", begin+size, cur())
	else
		print(" - frame size ok")
	end

	seek(begin+size)
	return
end

