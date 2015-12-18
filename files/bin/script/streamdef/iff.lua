-- riff解析
function align_chunk()
	if (cur() & 1) == 1 then
		seekoff(1)
	end
end

function chunk()
	local id   = rstr ("ckID",   4)
	local size = rbyte("ckSize", 4)

	if id == "RIFF" then
		little_endian(true)
		riff_chunk_data(reverse_32(size))
	elseif id == "FORM" then
		form_chunk_data(size)
	elseif id == "LIST" then
		if lstr(4) == "movi" then
			enable_print(false)
		end
		list_chunk_data(size)
	elseif id == "fmt " then
		fmt_chunk_data()
	elseif id == "idx1" then
		idx1_chunk_data(size)
	elseif id == "COMM" then
		comm_chunk_data()
	else
		-- rbyte("ckData", size)
		tbyte("ckData", size, __out_dir__.."iff_ckdata.dat")
	end

	align_chunk()
end

function riff_chunk_data(size)
	local name = rstr("riff_name", 4)
	sprint("  riff-"..name)
	
	local ed = cur() + size - 4
	while ed > cur() do
		chunk()
	end
end

function form_chunk_data(size)
	local name = rstr("form_name", 4)
	sprint("  form-"..name)
	
	local ed = cur() + size -4
	while ed > cur() do
		chunk()
	end
end

function list_chunk_data(size)
	local name = rstr("list_name", 4)
	sprint("  list-"..name)
	
	local ed = cur() + size - 4
	while ed > cur() do
		chunk()
	end
end

function idx1_chunk_data(size)
	sprint("  idx1")
	local ed = cur() + size
	while cur() < ed do
		rstr ("dwChunkId", 4)
		rbyte("dwFlags",   4)
		rbyte("dwOffset",  4)
		rbyte("dwSize",    4)
	end
end

function fmt_chunk_data()
	rbyte("format",                             2)
	rbyte("channels",                           2)
	rbyte("samplerate",                         4)
	rbyte("bytepersec",                         4)
	rbyte("block_size(smaple_x_channel)",       2)
	rbyte("bit_depth",                          2)
end

function comm_chunk_data(size)
	if get("form_name") == "AIFF" then
		print("this stream is AIFF")
		rbyte("numChannels",     2)  -- /* # audio channels */
		rbyte("numSampleFrames", 4)  -- /* # sample frames = samples/channel */
		rbyte("sampleSize",      2)  -- /* # bits/sample */
		rbit ("sampleRate",      80) -- /* sample_frames/sec */
	elseif get("form_name") == "AIFC" then
		print("this stream is AIFF-C")
		rbyte("numChannels",     2)  -- /* # audio channels */
		rbyte("numSampleFrames", 4)  -- /* # sample frames = samples/channel */
		rbyte("sampleSize",      2)  -- /* # bits/sample */
		rbit ("sampleRate",      80) -- /* sample_frames/sec */
		rbyte("compressionType", 4)  -- /* compression type ID code */
		rbyte("pstring_length",  1)  -- パスカル文字列長
		rstr ("compressionName", get("pstring_length"))	-- /* human-readable compression type name */
	else
		assert("unsupported", get("form_name"))
	end
end

--enable_print(true)
while cur() < get_size() do
	chunk()
end
