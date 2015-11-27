-- mp3解析
-- ストリーム解析
-- 途中、、

local syncword = 0xfff
local stereo = 0 -- '00'
local joint_stereo = 1 --  '01'  (intensity_stereo and/or ms_stereo)
local dual_channel = 2 --  '10' 
local single_channel = 3 --  '11'
local previous_syncword

local val_0__4

function rsyncsafe_int32()
	local val = 0
	rbit("marker", 1)
	val = (rbit("bit[27..21]", 7) << 21)
	rbit("marker", 1)
	val = val + (rbit("bit[20..14]", 7) << 14)
	rbit("marker", 1)
	val = val + (rbit("bit[13..7]", 7) << 7)
	rbit("marker", 1)
	val = val + rbit("bit[6..0]", 7)
	set("syncsafe_integer", val)
	return val
end

function check_ID3v2()
	local version
	if lstr(3) ~= "ID3" then
		return
	end

	cstr("header", 3, "ID3")

	rbyte("ID3_version_major", 1)
	rbyte("ID3_version_minor", 1)
	if get("ID3_version_major") == 2 then
		version = "v2.2.0"
		rbit("asynchronous_flag", 1)
		rbit("compress", 1)
		cbit("reserved", 6, 0)
	elseif get("ID3_version_major") == 3 and get("ID3_version_minor") == 0 then
		version = "v2.3.0"
		rbit("asynchronous_flag", 1)
		rbit("extension_flag", 1)
		rbit("testing_flag", 1)
		cbit("reserved", 5, 0)
	elseif (get("ID3_version_major") == 3 and get("ID3_version_minor") == 1)
	or     (get("ID3_version_major") == 4 and get("ID3_version_minor") == 0) then
		version = "v2.4.0"
		rbit("asynchronous_flag", 1)
		rbit("extension_flag", 1)
		rbit("testing_flag", 1)
		rbit("footer_flag", 1)
		cbit("flags", 4, 0)
	end
	
	local id3v2_size = rsyncsafe_int32()
	set("id3v2_size", id3v2_size)

	if version == "v2.3.0" then
		rbyte("extended_header_size", 4)
		rbit("crc_flag", 1)
		cbit("reserved", 15, 0)
		rbyte("extension_flag", 2)
		rbyte("padding_size", 4)
		if get("crc_flag") ~= 0 then
			rbyte("crc_data", 4)
		end
	elseif version == "v2.4.0" then
		set("extended_header_size", rsyncsafe_int32())
		rbit("flag_size", 8, 1)
		rbit("reserved", 1, 0)
		rbit("update_flag", 1, 0)
		rbit("crc_flag", 1, 0)
		rbit("limitation_flag", 1, 0)
		rbit("reserved", 4, 0)
		if get("crc_flag") ~= 0 then
			rbyte("crc_data", 5)
		end
		if get("limitation_flag") ~= 0 then
			rbit("tagsize_limitation", 2)
			rbit("text_code_limitation", 1)
			rbit("text_size_limitation", 2)
			rbit("picture_format_limitation", 2)
			rbit("picture_size_limitation", 2)
		end
	end

	print("====================================================")
	print("ID3"..version)
	while true do
		if ID3_frame(version) == false then
			break
		end
	end
	print("====================================================")
end

function ID3_frame(version)
	local begin = cur()
	local frame_id
	local frame_size

	if version == "v2.2.0" then
		if string.match(lstr(3), "[A-Z0-9][A-Z0-9][A-Z0-9]") == nil then
			return false
		end
		frame_id = rstr("frame_id", 3)
		frame_size = rbyte("frame_size", 3)
	elseif version == "v2.3.0" then
		if string.match(lstr(4), "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]") == nil then
			return false
		end
		frame_id = rstr("frame_id", 4)
		frame_size = rbyte("frame_size", 4)
		rbit("discaed_tag_update_flag", 1)
		rbit("discaed_file_update_flag", 1)
		rbit("read_only_flag", 1)
		cbit("reserved", 5, 0)
		rbit("compressed_flag", 1)
		rbit("enclypted_flag", 1)
		rbit("group_flag", 1)
		cbit("reserved", 5, 0)
		if get("compressed_flag") ~= 0 then
			rbyte("original_size", 4)
		end
		if get("enclypted_flag") ~= 0 then
			rbyte("enclyption_type", 1)
		end
	elseif version == "v2.4.0" then
		if string.match(lstr(4), "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]") == nil then
			return false
		end
		frame_id = rstr("frame_id", 4)
		frame_size = rsyncsafe_int32()
		set("frame_size", frame_size)
		cbit("reserved", 1, 0)
		rbit("discaed_tag_update_flag", 1)
		rbit("discaed_file_update_flag", 1)
		rbit("read_only", 1)
		cbit("reserved", 4, 0)
		cbit("reserved", 1, 0)
		rbit("group_flag", 1)
		cbit("reserved", 2, 0)
		rbit("compressed_flag", 1)
		rbit("enclypted_flag", 1)
		rbit("asynchronous_flag", 1)
		rbit("original_size_flag", 1)
		if get("compressed_flag") ~= 0 then
			rbyte("original_size", 4)
		end
		if get("enclypted_flag") ~= 0 then
			rbyte("enclyption_type", 1)
		end
	end

	if     frame_id == "TT2" or frame_id == "TIT2" then rbyte("encode", 1) print("title       ", rstr("frame_data", frame_size-1))
	elseif frame_id == "TP1" or frame_id == "TPE1" then rbyte("encode", 1) print("artist      ", rstr("frame_data", frame_size-1))
	elseif frame_id == "TP2" or frame_id == "TPE2" then rbyte("encode", 1) print("album_artist", rstr("frame_data", frame_size-1))
	elseif frame_id == "TAL" or frame_id == "TALB" then rbyte("encode", 1) print("album       ", rstr("frame_data", frame_size-1))
	elseif frame_id == "TYE" or frame_id == "TYER" then rbyte("encode", 1) print("year        ", rstr("frame_data", frame_size-1))
	elseif frame_id == "COM" or frame_id == "COMM" then rbyte("encode", 1) print("comment     ", rstr("frame_data", frame_size-1))	
	elseif frame_id == "TRK" or frame_id == "TRCK" then rbyte("encode", 1) print("track       ", rstr("frame_data", frame_size-1))
	elseif frame_id == "TCO" or frame_id == "TCON" then rbyte("encode", 1) print("genre       ", rstr("frame_data", frame_size-1))
	elseif frame_id == "PIC" or frame_id == "APIC" then
		print("export picture data --> ".."pic"..hexstr(frame_size)..".jpg")
		rbyte("header", 6)
		tbyte("picture_data", frame_size-6, __stream_dir__.."pic"..hexstr(frame_size)..".jpg")
	else
		print("unknown frame_id", frame_id)
		rbyte("encode", 1)
		rstr("unknown_frame_data", frame_size-1)
	end
	return true
end

function check_ID3v1()
	local begin = cur()
	seek(get_size() - 128)
	if gstr(3) ~= "TAG" then
		seek(begin)
		return
	end

	seek(begin)
end

function next_start_code()
	local bit = select(2, cur())
	if bit ~= 0 then
		cbit("zero_bit", 8-1, 0)
	end
	while lbyte(3) ~= 0x000001 do
		cbyte("zero_byte", 1, 0)
	end
end

function sequence(size)
	while cur() < size do
		check_progress(false)
		if lbit(12) == syncword then
			frame()
		else
			seekoff(1)
			fbyte(0xff)
		end
	end
end

function frame()
	header()

	error_check()

	sprint("skip audio_data and ancillary_data")
	-- audio_data()
	-- ancillary_data()
end

function header()
	cbit("syncword", 12, syncword) -- bits bslbf
	rbit("ID", 1) -- bit bslbf
	rbit("layer", 2) -- bits bslbf
	rbit("protection_bit", 1) -- bit bslbf
	rbit("bitrate_index", 4) -- bits bslbf
	rbit("sampling_frequency", 2) -- bits bslbf
	rbit("padding_bit", 1) -- bit bslbf
	rbit("private_bit", 1) -- bit bslbf
	rbit("mode", 2) -- bits bslbf
	rbit("mode_extension", 2) -- bits bslbf
	rbit("copyright", 1) -- bit bslbf
	rbit("original/home", 1) -- bit bslbf
	rbit("emphasis", 2) -- bits bslbf
end

function error_check()
	if get("protection_bit") == 0 then
		rbit("crc_check", 16) -- bits rpchof
	end
end

-- 各種テーブル[ch][gr]は配列の次元を入れ替えて[gr][ch]として保存
local scfsi = {}
local blocksplit_flag = {}
local block_type = {}
local switch_point = {}
local switch_point_l = {}
local switch_point_s = {}
local scalefac_compress = {}
local part2_3_length = {}

function audio_data()
	print("audio_data - return")
	
	if get("mode") == single_channel then
		rbit("main_data_end", 9) -- bits uimsbf
		rbit("private_bits",  5) -- bits bslbf
		for scfsi_band = 0, 4-1 do
			scfsi[scfsi_band] = rbit("scfsi[scfsi_band]", 1) -- bits bslbf
		end

		for gr=0, 2-1 do
			part2_3_length[gr] = rbit("part2_3_length[gr]", 12) -- bits uimsbf
			rbit("big_values[gr]", 9) -- bits uimsbf
			rbit("global_gain[gr]", 8) -- bits uimsbf
			scalefac_compress[gr] = rbit("scalefac_compress[gr]", 4) -- bits bslbf
			blocksplit_flag[gr] = rbit("blocksplit_flag[gr]", 1) -- bitbslbf
			if blocksplit_flag[gr] then
				block_type[gr] = rbit("block_type[gr]", 2) -- bits bslbf
				switch_point[gr] = rbit("switch_point[gr]", 1) -- bits uimsbf
				if switch_point[gr] == 0 then
					switch_point_l[gr] = 0
					switch_point_s[gr] = 0
				else 
					switch_point_l[gr] = 8
					switch_point_s[gr] = 3
				end
				for region=0, 2-1 do
					rbit("table_select[region][gr]", 5) -- bits bslbf
				end
				for window=0, 3-1 do
					rbit("subblock_gain[window][gr]", 3) -- bits uimsbf
				end
			else
				for region=0, 3-1 do
					rbit("table_select[region][gr]",  5) -- bits bslbf
					rbit("region_address1[gr]",  4) -- bits bslbf
					rbit("region_address2[gr]",  3) -- bits bslbf
				end
			end
			rbit("preflag[gr]",  1) -- bitbslbf
			rbit("scalefac_scale[gr]",  1) -- bitbslbf
			rbit("count1table_select[gr]",  1) -- bitbslbf
		end
		--[[
			The main_data follows. It does not follow the above side information in
			the bitstream. The main_data ends at a location in the main_data
			bitstream preceding the frame header of the following frame at an offset
			given by the value of main_data_end (see definition of main_data_end and
			3-Annex Fig.3-A.7.1)
		--]]
		for gr=0, 2-1 do
			if blocksplit_flag[gr] == 1
			and block_type[gr] == 2 then
				for cb=0, switch_point_l[gr]-1 do
					if scfsi[cb]==0 or gr==0 then
						rbit("scalefac[cb][gr]", val_0__4) -- bits uimsbf
					end
				end

				for cb=switch_point_s[gr], cblimit_short-1 do
					for window=0, 3-1 do
						if (scfsi[cb]==0) or (gr==0) then
							rbit("scalefac[cb][window][gr]", val_0__4) -- bits uimsbf
						end
					end
				end
			else
				for cb=0, cblimit-1 do
					if (scfsi[cb]==0) or (gr==0) then
						rbit("scalefac[cb][gr]", val_0__4) -- bits uimsbf
					end
				end
			end
			rbit("Huffmancodebits", (part2_3_length-part2_length)) -- bits bslbf
		end
		
		while position ~= main_data_end do
			rbit("ancillary_bit", 1) -- bitbslbf
		end
	end

	if (mode==stereo) or (mode==dual_channel) or (mode==ms_stereo) then
		rbit("main_data_end", 9) -- bits uimsbf
		rbit("private_bits", 3) -- bits bslbf
		for ch=0, 2-1 do
			for scfsi_band=0, 4-1 do
				rbit("scfsi[scfsi_band][ch]", 1) -- bits bslbf
			end
		end
		for gr=0, 2-1 do
			for ch=0, 2-1 do
				part2_3_length[ch] = {}
				part2_3_length[ch][gr] = rbit("part2_3_length[gr][ch]", 12) -- bits uimsbf
				rbit("big_values[gr][ch]", 9) -- bits uimsbf
				rbit("global_gain[gr][ch]", 8) -- bits uimsbf
				rbit("scalefac_compress[gr][ch]", 4) -- bits bslbf
				rbit("blocksplit_flag[gr][ch]", 1) -- bitbslbf
			end
		end
		if blocksplit_flag[gr][ch] then
			rbit("block_type[gr][ch]", 2) -- bits bslbf
			rbit("switch_point[gr][ch]", 1) -- bits uimsbf
			for region=0, 2-1 do
				rbit("table_select[region][gr][ch]", 5) -- bits bslbf
			end
			for window=0, 3-1 do
				rbit("subblock_gain[window][gr][ch]", 3) -- bits uimsbf
			end
		else
			for region=0, 3-1 do
				rbit("table_select[region][gr][ch]", 5) -- bits bslbf
			end
			rbit("region_address1[gr][ch]", 4) -- bits bslbf
			rbit("region_address2[gr][ch]", 3) -- bits bslbf
		end
		rbit("preflag[gr][ch]", 1) -- bitbslbf
		rbit("scalefac_scale[gr][ch]", 1) -- bitbslbf
		rbit("count1table_select[gr][ch]", 1) -- bitbslbf
		--[[
			The main_data follows. It does not follow the above side information in
			the bitstream. The main_data ends at a location in the main_data
			bitstream preceding the frame header of the following frame at an offset
			given by the value of main_data_end.
		--]]
		for gr=0, 2-1 do
			for ch=0, 2-1 do
				if blocksplit_flag[gr][ch] == 1 and block_type[gr][ch] == 2 then
					for cb=0, switch_point_l[gr][ch]-1 do
						if (scfsi[cb]==0) or (gr==0) then
							rbit("scalefac[cb][gr][ch]", val_0__4) -- bits uimsbf
						end
					end
					for cb=switch_point_s[gr][ch], cb<cblimit_short-1 do
						for window=0, 3-1 do
							if (scfsi[cb]==0) or (gr==0) then
								rbit("scalefac[cb][window][gr][ch]", val_0__4) -- bits uimsbf
							end
						end
					end
				else
					for cb=0, cblimit-1 do
						if (scfsi[cb]==0) or (gr==0) then
							rbit("scalefac[cb][gr][ch]", val_0__4) -- bits uimsbf
						end
					end
				end
				rbit("Huffmancodebits", (part2_3_lengthpart2_length)) -- bits bslbf 
				while position ~= main_data_end do
					rbit("ancillary_bit", 1) -- bitbslbf
				end
			end
		end
	end
end

function ancillary_data()
	while lbit(12) ~= syncword do
		rbit("ancillary_bit", 1) -- bitbslbf
	end
end

function mp3(size)
	check_ID3v2()
	check_ID3v1()
	sequence(size)
end

enable_print(false)


-- バグ、lbitを挟むとrbitがマイナスになる
--enable_print(true)
--rbit("hoge", 1) -- bitbslbf
--lbit(12)
--rbit("hoge", 1) -- bitbslbf
--rbit("hoge", 1) -- bitbslbf
--rbit("hoge", 1) -- bitbslbf
--rbit("hoge", 1) -- bitbslbf

mp3(get_size())

