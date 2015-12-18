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

function curbit()
	local byte, bit = cur()
	return byte * 8 + bit
end

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
	
	-- タグヘッダ
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

	-- 拡張ヘッダ
	if version == "v2.3.0" then
		if get("extension_flag") ~= 0 then
			rbyte("extended_header_size", 4)
			rbit("crc_flag", 1)
			cbit("reserved", 15, 0)
			rbyte("extension_flag", 2)
			rbyte("padding_size", 4)
			if get("crc_flag") ~= 0 then
				rbyte("crc_data", 4)
			end
		end
	elseif version == "v2.4.0" then
		if get("extension_flag") ~= 0 then
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
	end

	-- フレーム
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
		local tag = lstr(3)
		--print(tag)
		if string.match(tag, "[A-Z0-9][A-Z0-9][A-Z0-9]") == nil then
			return false
		end
		frame_id = rstr("frame_id", 3)
		frame_size = rbyte("frame_size", 3)
	elseif version == "v2.3.0" then
		local tag = lstr(4)
		--print(tag)
		if string.match(tag, "[A-Z0-9][A-Z0-9][A-Z0-9]") == nil then
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
		local tag = lstr(4)
		--print(tag)
		if string.match(tag, "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]") == nil then
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

	push("ID3v2_frame")

	if     frame_id == "TT2" or frame_id == "TIT2" then rbyte("encode", 1) print("Title        : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TP1" or frame_id == "TPE1" then rbyte("encode", 1) print("Artist       : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TP2" or frame_id == "TPE2" then rbyte("encode", 1) print("Album artist : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TAL" or frame_id == "TALB" then rbyte("encode", 1) print("Album        : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TYE" or frame_id == "TYER" then rbyte("encode", 1) print("Year         : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "COM" or frame_id == "COMM" then rbyte("encode", 1) print("Comment      : "..rstr("frame_data", frame_size-1))	
	elseif frame_id == "TRK" or frame_id == "TRCK" then rbyte("encode", 1) print("Track        : "..rstr("frame_data", frame_size-1))	
	elseif frame_id == "TCO" or frame_id == "TCON" then rbyte("encode", 1) print("Genre        : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TCM" or frame_id == "TCOM" then rbyte("encode", 1) print("Composer     : "..rstr("frame_data", frame_size-1))	
	elseif frame_id == "TPA" or frame_id == "TPOS" then rbyte("encode", 1) print("Disk no.     : "..rstr("frame_data", frame_size-1))	
	elseif frame_id == "TEN" or frame_id == "TENC" then rbyte("encode", 1) print("Encoder      : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TCP" or frame_id == "TCMP" then rbyte("encode", 1) print("Compilation  : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TBP" or frame_id == "TBPM" then rbyte("encode", 1) print("Bpm          : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "TT1" or frame_id == "TIT1" then rbyte("encode", 1) print("Group        : "..rstr("frame_data", frame_size-1))
	elseif frame_id == "PIC" or frame_id == "APIC" then
		print("export picture data --> ".."pic"..hexstr(frame_size)..".jpg")
		local ofs = fstr("FF D8", 100, false)
		if ofs ~= 100 then
			rbyte("header", ofs)
			tbyte("picture_data", frame_size-ofs, __out_dir__.."pic"..hexstr(frame_size)..".jpg")
		end
	else
		rbyte("encode", 1)
		print("unknown_info", frame_id, rstr("unknown_frame_data", frame_size-1))
	end
	
	pop("ID3v2_frame")
	
	return true
end

function check_ID3v1()
	local begin = cur()
	seek(get_size() - 128)
	if lstr(3) ~= "TAG" then
		seek(begin)
		return
	end

	push("ID3v1")
	print("Header     : ", rstr("Header", 3))
	print("Title      : ", rstr("Title", 30))
	print("Artist     : ", rstr("Artist", 30))
	print("Album      : ", rstr("Album", 30))
	print("Year       : ", rstr("Year", 4))
	print("Comment    : ", rstr("Comment", 28))
	print("Track_flag : ", rbyte("Track_flag", 1))
	print("Track      : ", rbyte("Track", 1))
	print("Genru      : ", rbyte("Genru", 1))
	pop("ID3v1")

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
		seek(cur(), 0)
		if lbit(12) == syncword then
			frame()
		else
			print("# syncword not found.", hexstr(cur()))
			seek(cur()+1, 0)
			fbyte(0xff)
		end
	end
end

local bitrate_table = {
    false,
	32  * 1000,
	40  * 1000,
	48  * 1000,
	56  * 1000,
	64  * 1000,
	80  * 1000,
	96  * 1000,
	112 * 1000,
	128 * 1000,
	160 * 1000,
	192 * 1000,
	224 * 1000,
	256 * 1000,
	320 * 1000}
local sampling_freq_table = {
	44100,
	48000,
	32000
}
function frame()
	local begin = cur()
	nest_call("header", header)
	
	-- mp3は計算でサイズ取得が必要orz
	local frame_size = math.floor(144 * bitrate_table[get("bitrate_index")+1] / sampling_freq_table[get("sampling_frequency")+1]) 
    if get("padding_bit") ~= 0 then
    	frame_size = frame_size + 1
    end
	
	nest_call("error_check", error_check)
	nest_call("audio_data", audio_data)
	-- nest_call("ancillary_data", ancillary_data)

	seek(begin + frame_size)
end


function header()
	cbit("syncword", 12, syncword) -- bits bslbf
	rbit("ID", 1) -- bit bslbf
	cbit("layer", 2, 1) -- bits bslbf
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
local cblimit_short = 12
local cblimit = 21
local scfsi = {}
local blocksplit_flag = {}
local block_type = {}
local switch_point = {}
local switch_point_l = {}
local switch_point_s = {}
local scalefac_compress = {}
local part2_3_length = {}

local slen_table = {
	slen1={0, 0, 0, 0, 3, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4},
	slen2={0, 1, 2, 3, 0, 1, 2, 3, 1, 2, 3, 1, 2, 3, 2, 3}}

function audio_data()	
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
		
		-- The main_data follows. It does not follow the above side information in
		-- the bitstream. The main_data ends at a location in the main_data
		-- bitstream preceding the frame header of the following frame at an offset
		-- given by the value of main_data_end (see definition of main_data_end and
		-- 3-Annex Fig.3-A.7.1)
		
		
		
		if true then
			seekoff(0, get("main_data_end"))
			return
		end
		
		
		
		for gr=0, 2-1 do
			if blocksplit_flag[gr] == 1
			and block_type[gr] == 2 then
				for cb=0, switch_point_l[gr]-1 do
					if scfsi[cb]==0 or gr==0 then
						rbit("scalefac[cb][gr]", slen_table.slen1[scalefac_compress[gr][ch]+1]) -- bits uimsbf
					end
				end

				for cb=switch_point_s[gr], cblimit_short-1 do
					for window=0, 3-1 do
						if (scfsi[cb]==0) or (gr==0) then
							rbit("scalefac[cb][window][gr]", slen_table.slen2[scalefac_compress[gr][ch]+1]) -- bits uimsbf
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

	if (get("mode") == stereo) or (get("mode") == dual_channel) or (get("mode") == joint_stereo) then
		rbit("main_data_end", 9) -- bits uimsbf
		rbit("private_bits", 3) -- bits bslbf
		for ch=0, 2-1 do
			scfsi[ch] = {}
			for scfsi_band=0, 4-1 do
				scfsi[ch][scfsi_band] = rbit("scfsi[scfsi_band][ch]", 1) -- bits bslbf
			end
		end
		for gr=0, 2-1 do
			part2_3_length[gr] = {}
			blocksplit_flag[gr] = {}
			scalefac_compress[gr] = {}
			block_type[gr] = {}
			switch_point[gr] = {}
			switch_point_l[gr] = {}
			switch_point_s[gr] = {}
			for ch=0, 2-1 do
				-- スケールファクタービット列(part2)とハフマン符号ビット列（part3）のビット長の合計
				part2_3_length[gr][ch] = rbit("part2_3_length[gr][ch]", 12) -- bits uimsbf

				rbit("big_values[gr][ch]", 9) -- bits uimsbf
				rbit("global_gain[gr][ch]", 8) -- bits uimsbf
				scalefac_compress[gr][ch] = rbit("scalefac_compress[gr][ch]", 4) -- bits bslbf
				blocksplit_flag[gr][ch] = rbit("blocksplit_flag[gr][ch]", 1) -- bitbslbf
				if blocksplit_flag[gr][ch] ~= 0 then
					block_type[gr][ch] = rbit("block_type[gr][ch]", 2) -- bits bslbf 
					switch_point[gr][ch] = rbit("switch_point[gr][ch]", 1) -- bits uimsbf
					if switch_point[gr] == 0 then
						switch_point_l[gr][ch] = 0
						switch_point_s[gr][ch] = 0
					else 
						switch_point_l[gr][ch] = 8
						switch_point_s[gr][ch] = 3
					end
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
			end
		end

		-- The main_data follows. It does not follow the above side information in
		-- the bitstream. The main_data ends at a location in the main_data
		-- bitstream preceding the frame header of the following frame at an offset
		-- given by the value of main_data_end.
        -- 
		
		
		
		if true then
			seekoff(0, get("main_data_end"))
			return
		end
		
		
		
		local main_data_beg = curbit()
		for gr=0, 2-1 do
			for ch=0, 2-1 do
				print("gr", gr, "ch", ch)
				if block_type[gr][ch] == 0 then print("reserved")
				elseif block_type[gr][ch] == 1 then print("start block")
				elseif block_type[gr][ch] == 2 then print("3 short windows")
				elseif block_type[gr][ch] == 3 then print("end block")
				end
				if switch_point[gr][ch] == 0 then print("not_mixed")
				elseif switch_point[gr][ch] == 1 then print("mixed")
				end

				if blocksplit_flag[gr][ch] == 1 and block_type[gr][ch] == 2 then
					for cb=0, switch_point_l[gr][ch]-1 do
						if (scfsi[cb]==0) or (gr==0) then
							rbit("scalefac[cb][gr][ch]", slen_table.slen1[scalefac_compress[gr][ch]+1]) -- bits uimsbf
						end
					end
					for cb=switch_point_s[gr][ch], cblimit_short-1 do
						for window=0, 3-1 do
							if (scfsi[cb]==0) or (gr==0) then
								rbit("scalefac[cb][window][gr][ch]", slen_table.slen2[scalefac_compress[gr][ch]+1]) -- bits uimsbf
							end
						end
					end
				else
					for cb=0, cblimit-1 do
						if (scfsi[cb]==0) or (gr==0) then
							if cb <= 10 then
								rbit("scalefac[cb][gr][ch]", slen_table.slen1[scalefac_compress[gr][ch]+1]) -- bits uimsbf
							else
								rbit("scalefac[cb][gr][ch]", slen_table.slen2[scalefac_compress[gr][ch]+1]) -- bits uimsbf
							end
						end
					end
				end
	
	
	
				-- seekoff(0, get("main_data_end") - (curbit() - main_data_beg))
				-- break
				-- rbit("Huffmancodebits", part2_3_length[gr][ch]) -- bits bslbf 


			end
		end

		-- while curbit() - main_data_begin ~= get("main_data_end") do
		-- 	rbit("ancillary_bit", 1) -- bitbslbf
		-- end
	end
end

function ancillary_data()
	while lbit(12) ~= syncword do
		rbit("ancillary_bit", 1) -- bitbslbf
	end
end

function mp3(size)
	nest_call("check_ID3v2", check_ID3v2)
	nest_call("check_ID3v1", check_ID3v1)
	sequence(size)
end


-- enable_print(true)
mp3(get_size())

