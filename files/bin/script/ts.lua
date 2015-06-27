-- ts解析
-- ./a.out test.ts

dofile(__exec_dir__.."script/pes.lua")

-- ストリーム解析
local ts_packet_size = 188
local pmt_pid = nil
local pes_buf_array = {}
local analyse_data_byte = true
local TYPE_PES = 0
local TYPE_PAT = 1
local TYPE_PMT = 2
local pes_print = false

function descriptor()
	local begin = cur()
	
	rbit("descriptor_tag",    8) -- uimsbf
	rbit("descriptor_length", 8) -- uimsbf

	local descriptor_tag = get("descriptor_tag")
	local descriptor_length = get("descriptor_length")	

	if     descriptor_tag == 0  then print("descriptor_tag="..hexstr(descriptor_tag), "reserved")
	elseif descriptor_tag == 1  then print("descriptor_tag="..hexstr(descriptor_tag), "forbidden")
	elseif descriptor_tag == 2  then print("descriptor_tag="..hexstr(descriptor_tag), "video_stream_descriptor")
	elseif descriptor_tag == 3  then print("descriptor_tag="..hexstr(descriptor_tag), "audio_stream_descriptor")
	elseif descriptor_tag == 4  then print("descriptor_tag="..hexstr(descriptor_tag), "hierarchy_descriptor")
	elseif descriptor_tag == 5  then registration_descriptor(descriptor_length)
	elseif descriptor_tag == 6  then print("descriptor_tag="..hexstr(descriptor_tag), "data_stream_alignment_descriptor")
	elseif descriptor_tag == 7  then print("descriptor_tag="..hexstr(descriptor_tag), "target_background_grid_descriptor")
	elseif descriptor_tag == 8  then print("descriptor_tag="..hexstr(descriptor_tag), "video_window_descriptor")
	elseif descriptor_tag == 9  then print("descriptor_tag="..hexstr(descriptor_tag), "CA_descriptor")
	elseif descriptor_tag == 10 then print("descriptor_tag="..hexstr(descriptor_tag), "ISO_639_language_descriptor")
	elseif descriptor_tag == 11 then print("descriptor_tag="..hexstr(descriptor_tag), "system_clock_descriptor")
	elseif descriptor_tag == 12 then print("descriptor_tag="..hexstr(descriptor_tag), "multiplex_buffer_utilization_descriptor")
	elseif descriptor_tag == 13 then print("descriptor_tag="..hexstr(descriptor_tag), "copyright_descriptor")
	elseif descriptor_tag == 14 then print("descriptor_tag="..hexstr(descriptor_tag), "maximum_bitrate_descriptor")
	elseif descriptor_tag == 15 then print("descriptor_tag="..hexstr(descriptor_tag), "private_data_indicator_descriptor")
	elseif descriptor_tag == 16 then print("descriptor_tag="..hexstr(descriptor_tag), "smoothing_buffer_descriptor")
	elseif descriptor_tag == 17 then print("descriptor_tag="..hexstr(descriptor_tag), "STD_descriptor")
	elseif descriptor_tag == 18 then print("descriptor_tag="..hexstr(descriptor_tag), "IBP_descriptor")
	elseif descriptor_tag == 27 then print("descriptor_tag="..hexstr(descriptor_tag), "MPEG-4_video_descriptor")
	elseif descriptor_tag == 28 then print("descriptor_tag="..hexstr(descriptor_tag), "MPEG-4_audio_descriptor")
	elseif descriptor_tag == 29 then print("descriptor_tag="..hexstr(descriptor_tag), "IOD_descriptor")
	elseif descriptor_tag == 30 then print("descriptor_tag="..hexstr(descriptor_tag), "SL_descriptor")
	elseif descriptor_tag == 31 then print("descriptor_tag="..hexstr(descriptor_tag), "FMC_descriptor")
	elseif descriptor_tag == 32 then print("descriptor_tag="..hexstr(descriptor_tag), "external_ES_ID_descriptor")
	elseif descriptor_tag == 33 then print("descriptor_tag="..hexstr(descriptor_tag), "MuxCode_descriptor")
	elseif descriptor_tag == 34 then print("descriptor_tag="..hexstr(descriptor_tag), "FmxBufferSize_descriptor")
	elseif descriptor_tag == 35 then print("descriptor_tag="..hexstr(descriptor_tag), "multiplexbuffer_descriptor")
	elseif descriptor_tag == 36 then print("descriptor_tag="..hexstr(descriptor_tag), "content_labeling_descriptor")
	elseif descriptor_tag == 37 then print("descriptor_tag="..hexstr(descriptor_tag), "metadata_pointer_descriptor")
	elseif descriptor_tag == 38 then print("descriptor_tag="..hexstr(descriptor_tag), "metadata_descriptor")
	elseif descriptor_tag == 39 then print("descriptor_tag="..hexstr(descriptor_tag), "metadata_STD_descriptor")
	elseif descriptor_tag == 40 then print("descriptor_tag="..hexstr(descriptor_tag), "AVC video descriptor")
	elseif descriptor_tag == 41 then print("descriptor_tag="..hexstr(descriptor_tag), "IPMP_descriptor (defined in ISO/IEC 13818-11, MPEG-2 IPMP)")
	elseif descriptor_tag == 42 then print("descriptor_tag="..hexstr(descriptor_tag), "AVC timing and HRD descriptor")
	elseif descriptor_tag == 43 then print("descriptor_tag="..hexstr(descriptor_tag), "MPEG-2_AAC_audio_descriptor")
	elseif descriptor_tag == 44 then print("descriptor_tag="..hexstr(descriptor_tag), "FlexMuxTiming_descriptor")
	elseif descriptor_tag == 45 then print("descriptor_tag="..hexstr(descriptor_tag), "MPEG-4_text_descriptor")
	elseif descriptor_tag == 46 then print("descriptor_tag="..hexstr(descriptor_tag), "MPEG-4_audio_extension_descriptor")
	elseif descriptor_tag == 47 then print("descriptor_tag="..hexstr(descriptor_tag), "auxiliary_video_stream_descriptor")
	elseif descriptor_tag == 48 then print("descriptor_tag="..hexstr(descriptor_tag), "SVC extension descriptor")
	elseif descriptor_tag == 49 then print("descriptor_tag="..hexstr(descriptor_tag), "MVC extension descriptor")
	elseif descriptor_tag == 50 then print("descriptor_tag="..hexstr(descriptor_tag), "J2K video descriptor")
	elseif descriptor_tag == 51 then print("descriptor_tag="..hexstr(descriptor_tag), "MVC operation point descriptor")
	elseif descriptor_tag == 52 then print("descriptor_tag="..hexstr(descriptor_tag), "MPEG2_stereoscopic_video_format_descriptor")
	elseif descriptor_tag == 53 then print("descriptor_tag="..hexstr(descriptor_tag), "Stereoscopic_program_info_descriptor")
	elseif descriptor_tag == 54 then print("descriptor_tag="..hexstr(descriptor_tag), "Stereoscopic_video_info_descriptor")
	elseif 19 <= descriptor_tag and descriptor_tag <= 26 then
		print("descriptor_tag="..hexstr(descriptor_tag), "Defined in ISO/IEC 13818-6")
	elseif 55 <= descriptor_tag and descriptor_tag <= 63 then
		print("descriptor_tag="..hexstr(descriptor_tag), "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 Reserved")
	elseif 64 <= descriptor_tag and descriptor_tag <= 255 then
		print("descriptor_tag="..hexstr(descriptor_tag), "User Private")
	else
		print("descriptor_tag="..hexstr(descriptor_tag), "unknown")
	end
	
	rbyte("remain data", get("descriptor_length") - (cur() - begin - 2))
end

function registration_descriptor(length)
	rstr("format_identifier", 4) -- 32 uimsbf
	for i = 1, length - 4 do
		rbit("additional_identification_info", 8) -- bslbf
	end
end

function adaptation_field()
--print("adaptation_field")
	local begin = cur()
	rbit("adaptation_field_length",                         8)
	if get("adaptation_field_length") == 0 then
		return
	end
	rbit("discontinuity_indicator",                         1)
	rbit("random_access_indicator",                         1)
	rbit("elementary_stream_priority_indicator",            1)
	rbit("PCR_flag",                                        1)
	rbit("OPCR_flag",                                       1)
	rbit("splicing_point_flag",                             1)
	rbit("transport_private_data_flag",                     1)
	rbit("adaptation_field_extension_flag",                 1)

	if get("PCR_flag") == 1 then
		rbit("program_clock_reference_base_upper1",         1)
		rbit("program_clock_reference_base",                32)
		rbit("reserved",                                    6)
		rbit("program_clock_reference_extension",           9)
		local PCR = get("program_clock_reference_base_upper1")*0x100000000
			+ get("program_clock_reference_base")
		store_recode(get("PID"), cur(), 0, PCR, false, false)
	end
	if get("OPCR_flag") == 1 then
		rbit("original_program_clock_reference_base",       33)
		rbit("reserved",                                    6)
		rbit("original_program_clock_reference_extension",  9)
	end
	if get("splicing_point_flag") == 1 then
		rbit("splice_countdown",                            8)
	end
	if get("transport_private_data_flag") == 1 then
		rbit ("transport_private_data_length",               8)
		dump()
		rbyte("private_data_byte",                           get("transport_private_data_length"))
	end
	if get("adaptation_field_extension_flag") == 1 then
		local begin = cur()
	    rbit("adaptation_field_extension_length",           8)
	    rbit("ltw_flag",                                    1)
	    rbit("piecewise_rate_flag",                         1)
	    rbit("seamless_splice_flag",                        1)
	    rbit("reserved",                                    5)
	    
		if get("ltw_flag") == 1 then
			rbit("ltw_valid_flag",                          1)
			rbit("ltw_offset",                              15)
		end
		
		if get("piecewise_rate_flag") == 1 then
	        rbit("reserved",                                2)
	        rbit("piecewise_rate",                          22)
		end
		
		if get("seamless_splice_flag") == 1 then
		    rbit("splice_type",                             4)
		    rbit("DTS_next_AU[32..30]",                     3)
		    rbit("marker_bit",                              1)
		    rbit("DTS_next_AU[29..15]",                     15)
		    rbit("marker_bit",                              1)
		    rbit("DTS_next_AU[14..0]",                      15)
		    rbit("marker_bit",                              1)
	    end

		rbyte("reserved", get("adaptation_field_extension_length") + 1 - (cur()-begin))
	end

	rbyte("a stuffing_byte", get("adaptation_field_length") + 1 - (cur() - begin))
end

function pat()
	local begin = cur()
	rbit("table_id",                                        8)
	rbit("section_syntax_indicator",                        1)
	rbit("'0'",                                             1)
	rbit("reserved",                                        2)
	rbit("section_length",                                  12)
	rbit("transport_stream_id",                             16)
	rbit("reserved",                                        2)
	rbit("version_number",                                  5)
	rbit("current_next_indicator",                          1)
	rbit("section_number",                                  8)
	rbit("last_section_number",                             8)

	local len = get("section_length") - 5 - 4
	local total = 0
	while total < len do
		rbit("program_number",                              16)
		rbit("reserved",                                    3)
		if get("program_number") == 0 then
		    rbit("network_PID",                             13)
		else
		    rbit("program_map_PID",                         13)
		    
		    -- 初めて見るPIDなら追加
		    pmt_pid = get("program_map_PID")
		    print("program_map_PID", hexstr(get("program_map_PID")))
		end
		total = total + 4 
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

function stream_type_to_string(stream_type, format_identifire)
	local ret1
	local ret2
	
	if     stream_type == 0x00 then ret1 = "ITU-T | ISO/IEC Reserved"
	elseif stream_type == 0x01 then ret1 = "[MPEG-1 Video]" -- ISO/IEC 11172-2 Video"
	elseif stream_type == 0x02 then ret1 = "[MPEG-2 Video]" -- Rec. ITU-T H.262 | ISO/IEC 13818-2 Video or ISO/IEC 11172-2 constrained parameter video stream"
	elseif stream_type == 0x03 then ret1 = "[MPEG-1 Audio]" -- ISO/IEC 11172-3 Audio"
	elseif stream_type == 0x04 then ret1 = "[MPEG-2 Video]" -- "ISO/IEC 13818-3 Audio"
	elseif stream_type == 0x05 then ret1 = "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 private_sections"
	elseif stream_type == 0x06 then ret1 = "[private data]" -- Rec. ITU-T H.222.0 | ISO/IEC 13818-1 PES packets containing private data"
	elseif stream_type == 0x07 then ret1 = "ISO/IEC 13522 MHEG"
	elseif stream_type == 0x08 then ret1 = "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 Annex A DSM-CC"
	elseif stream_type == 0x09 then ret1 = "Rec. ITU-T H.222.1"
	elseif stream_type == 0x0A then ret1 = "ISO/IEC 13818-6 type A"
	elseif stream_type == 0x0B then ret1 = "ISO/IEC 13818-6 type B"
	elseif stream_type == 0x0C then ret1 = "ISO/IEC 13818-6 type C"
	elseif stream_type == 0x0D then ret1 = "ISO/IEC 13818-6 type D"
	elseif stream_type == 0x0E then ret1 = "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 auxiliary"
	elseif stream_type == 0x0F then ret1 = "[ADTS MPEG-2 AAC]" -- "ISO/IEC 13818-7 Audio with ADTS transport syntax"
	elseif stream_type == 0x10 then ret1 = "ISO/IEC 14496-2 Visual"
	elseif stream_type == 0x11 then ret1 = "[LATM MPEG-4 Audio]" -- "ISO/IEC 14496-3 Audio with the LATM transport syntax as defined in ISO/IEC 14496-3"
	elseif stream_type == 0x12 then ret1 = "ISO/IEC 14496-1 SL-packetized stream or FlexMux stream carried in PES packets"
	elseif stream_type == 0x13 then ret1 = "ISO/IEC 14496-1 SL-packetized stream or FlexMux stream carried in ISO/IEC 14496_sections"
	elseif stream_type == 0x14 then ret1 = "ISO/IEC 13818-6 Synchronized Download Protocol"
	elseif stream_type == 0x15 then ret1 = "Metadata carried in PES packets"
	elseif stream_type == 0x16 then ret1 = "Metadata carried in metadata_sections"
	elseif stream_type == 0x17 then ret1 = "Metadata carried in ISO/IEC 13818-6 Data Carousel"
	elseif stream_type == 0x18 then ret1 = "Metadata carried in ISO/IEC 13818-6 Object Carousel"
	elseif stream_type == 0x19 then ret1 = "Metadata carried in ISO/IEC 13818-6 Synchronized Download Protocol"
	elseif stream_type == 0x1A then ret1 = "IPMP stream (defined in ISO/IEC 13818-11, MPEG-2 IPMP)"
	elseif stream_type == 0x1B then ret1 = "[H.264 / MPEG-4 AVC]"
	-- AVC video stream conforming to one or more profiles defined in Annex A of Rec. ITU-T H.264 |
	-- ISO/IEC 14496-10 or AVC video sub-bitstream of SVC as defined in 2.1.78 or MVC base view
	-- sub-bitstream, as defined in 2.1.85, or AVC video sub-bitstream of MVC, as defined in 2.1.88
	elseif stream_type == 0x1C then ret1 = "ISO/IEC 14496-3 Audio, without using any additional transport syntax, such as DST, ALS and SLS"
	elseif stream_type == 0x1D then ret1 = "ISO/IEC 14496-17 Text"
	elseif stream_type == 0x1E then ret1 = "Auxiliary video stream as defined in ISO/IEC 23002-3"
	elseif stream_type == 0x1F then ret1 = "SVC video sub-bitstream of an AVC video stream conforming to one or more profiles defined in Annex G of Rec. ITU-T H.264 | ISO/IEC 14496-10"
	elseif stream_type == 0x20 then ret1 = "MVC video sub-bitstream of an AVC video stream conforming to one or more profiles defined in Annex H of Rec. ITU-T H.264 | ISO/IEC 14496-10"
	elseif stream_type == 0x21 then ret1 = "Video stream conforming to one or more profiles as defined in Rec. ITU-T T.800 | ISO/IEC 15444-1"
	elseif stream_type == 0x22 then ret1 = "Additional view Rec. ITU-T H.262 | ISO/IEC 13818-2 video stream for service-compatible stereoscopic 3D services (see Notes 3 and 4)"
	elseif stream_type == 0x23 then ret1 = "Additional view Rec. ITU-T H.264 | ISO/IEC 14496-10 video stream conforming to one or more profiles defined in Annex A for service-compatible stereoscopic 3D services (see Notes 3 and 4)"
	elseif stream_type == 0x24 then ret1 = "[H.265 / HEVC]"
	elseif stream_type == 0x24 then ret1 = "[H.265 / HEVC]"
	elseif stream_type == 0x2A then ret1 = "[H.265 / HEVC]"
	elseif 0x24 <= stream_type and stream_type <= 0x7E then
		ret1 = "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 Reserved"
	elseif stream_type == 0x7F then
		ret1 = "IPMP stream"
	elseif 0x80 <= stream_type and stream_type <= 0xFF then
		ret1 = "User Private"
	elseif stream_type == 0x81 then
		 ret1 = "[AC3]"
	else
		print("unknown stream_type", stream_type)
	end
	
	if format_identifire == nil then
		ret2 = ""
	elseif format_identifire == "HEVC" then
		ret2 = "[HEVC]"
	else 
		ret2 = format_identifire
	end
	
	return ret1..ret2
end

function pmt()
	local begin = cur()
	rbit("table_id",                                        8) 
	rbit("section_syntax_indicator",                        1) 
	rbit("'0'",                                             1) 
	rbit("reserved",                                        2) 
	rbit("section_length",                                  12)
	rbit("program_number",                                  16)
	rbit("reserved",                                        2) 
	rbit("version_number",                                  5) 
	rbit("current_next_indicator",                          1) 
	rbit("section_number",                                  8) 
	rbit("last_section_number",                             8) 
	rbit("reserved",                                        3) 
	rbit("PCR_PID",                                         13)
	rbit("reserved",                                        4) 
	rbit("program_info_length",                             12)

	do_until(function() descriptor() end, cur() + get("program_info_length"))
	
	local len = get("section_length") - 4  - 9
		- get("program_info_length")
	local total = 0
	local num_es = 0
	while total < len do
		rbit("stream_type",                                 8)
		rbit("reserved",                                    3)
		rbit("elementary_PID",                              13)
		rbit("reserved",                                    4)
		rbit("ES_info_length",                              12)

		do_until(function() descriptor() end, cur() + get("ES_info_length"))
		
		-- 初めて見るPIDなら追加
		local buf = stream:new(1024*1024*3)
		buf:enable_print(pes_print)
	    pes_buf_array[get("elementary_PID")] = buf
		print("", stream_type_to_string(get("stream_type"), peek("format_identifier"))..
			" = "..hexstr(get("elementary_PID")))

		total = total + get("ES_info_length") + 5
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

function ts(size, target)
	local total = 0
	local no = 0
	local begin
	
	-- 初期TSパケット長
	if __stream_ext__ == ".tts"
	or __stream_ext__ == ".m2ts" then
		ts_packet_size = 192
	else
		ts_packet_size = 188
	end

	while total < size do
		no = no + 1
		begin = cur()
		check_progress()
	
		if ts_packet_size == 192 then
			rbyte("ATS", 4)
			-- printf("  ATS = %x(%fsec)", get("ATS"), get("ATS")/90000)
		end

		local ofs = fbyte(0x47, true)
		rbit("syncbyte", 8)
		if ofs ~= 0 then
			if ofs < 20 then -- 適当 208バイト
				ts_packet_size = ts_packet_size + ofs
			else
				ts_packet_size = 188
			end
			print("# discontinuous syncbyte --> size chagne to "..ts_packet_size)
		end

		rbit("transport_error_indicator",    1)
		rbit("payload_unit_start_indicator", 1)		
		rbit("transport_priority",           1)
		rbit("PID",                          13)
		rbit("transport_scrambling_control", 2)
		rbit("adaptation_field_control",     2)
		rbit("continuity_counter",           4)
		
		if get("payload_unit_start_indicator") == 1 and analyse_data_byte then
			payload(get("PID"))
		end
		
		if get("adaptation_field_control") & 2 == 2 then
			adaptation_field()
		end
		
		if get("adaptation_field_control") & 1 == 1 then
			if data_byte(target, get("PID"), ts_packet_size - (cur() - begin)) == true then
				if target==TYPE_PAT or target==TYPE_PMT then
					return
				end
			end
		end
		
		total = total + (cur()-begin)
	end
end

function data_byte(target, pid, size)
	if target == TYPE_PES then
		if analyse_data_byte == false then
			rbyte("data data_byte", size)
			return true
		elseif pes_buf_array[pid] ~= nil then
			-- バッファにデータ転送
			tbyte("data_byte", size, pes_buf_array[pid])
			return true
		else
			rbyte("unknown data", size)
			return false
		end
	elseif target == TYPE_PAT then
		if pid == 0 then
			if get("payload_unit_start_indicator")==1 then
				rbit("pointer_field", 8)
				pat()
				rbyte("stuffing", size)
				return true
			else
				assert(false, "# unsupported yet")
			end
		else
			rbyte("data_byte", size)
			return false
		end
	elseif target == TYPE_PMT then 
		if pid == pmt_pid then
			if get("payload_unit_start_indicator")==1 then
				rbit("pointer_field", 8)
				pmt()
				rbyte("stuffing", size)
				return true
			else
				assert(false, "# unsupported yet")
			end
		else
			rbyte("data_byte", size)
			return false
		end
	end
end

function payload(pid)
	local pes_buf = pes_buf_array[pid]
	if  pes_buf ~= nil then
		local ts_file = swap(pes_buf)
		if get_size() ~= cur() then
			local size, PTS, DTS = pes(buf, pid)
			store_recode(pid, cur(), size, false, PTS, DTS)
			if get_size() ~= cur() then
				rbyte("#unknown remain data", get_size() - cur())
			end
		end
		swap(ts_file)
	end
end

function store_recode(pid, offset, size, PCR, PTS, DTS)
	store("pid", pid)
	store("offset", cur())
	store("size", size)
	store("PCR", PCR)
	store("PTS", PTS)
	store("DTS", DTS)	
	PCR = PCR or 0
	PTS = PTS or 0
	DTS = DTS or 0
--	printf("%10d,%10d,%10d,%10.3f,%10.3f,%10.3f", pid, offset, size, PCR/90000, PTS/90000, DTS/90000)
end

function analyze()
	ts_print = false
	pes_print = false

	print("analyze PAT")
	seek(0)
	enable_print(ts_print)
	ts(1024*1024, TYPE_PAT)

	print("analyze PMT")
	seek(0)
	enable_print(ts_print)
	ts(1024*1024, TYPE_PMT)

	print("analyze PES")
	-- print("analyse data_byte? [y/n]")
	-- analyse_data_byte = io.read() == "y"
	analyse_data_byte = true
	seek(0)
	enable_print(ts_print)
	ts(get_size()-200, TYPE_PES)
end

open(__stream_path__)
print_status()
analyze()
save_as_csv(__stream_dir__.."out/ts.csv")
print_status()



