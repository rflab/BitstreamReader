-- ts解析
-- ./a.out test.ts

dofile(__exec_dir__.."script/pes.lua")

-- ストリーム解析
local ts_packet_size = 188
local pmt_pid = nil
local pes_buf_array = {}

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

function stream_type_to_string(stream_type)
	assert(stream_type)
	if     stream_type == 0x00 then return "[MPEG-1 Video]"-- ITU-T | ISO/IEC Reserved"
	elseif stream_type == 0x01 then return "[MPEG-2 Video]"-- ISO/IEC 11172-2 Video"
	elseif stream_type == 0x02 then return "[MPEG-1 Audio]"-- Rec. ITU-T H.262 | ISO/IEC 13818-2 Video or ISO/IEC 11172-2 constrained parameter video stream"
	elseif stream_type == 0x03 then return "[MPEG-2 Audio]"-- ISO/IEC 11172-3 Audio"
	elseif stream_type == 0x04 then return "ISO/IEC 13818-3 Audio"
	elseif stream_type == 0x05 then return "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 private_sections"
	elseif stream_type == 0x06 then return "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 PES packets containing private data"
	elseif stream_type == 0x07 then return "ISO/IEC 13522 MHEG"
	elseif stream_type == 0x08 then return "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 Annex A DSM-CC"
	elseif stream_type == 0x09 then return "Rec. ITU-T H.222.1"
	elseif stream_type == 0x0A then return "ISO/IEC 13818-6 type A"
	elseif stream_type == 0x0B then return "ISO/IEC 13818-6 type B"
	elseif stream_type == 0x0C then return "ISO/IEC 13818-6 type C"
	elseif stream_type == 0x0D then return "ISO/IEC 13818-6 type D"
	elseif stream_type == 0x0E then return "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 auxiliary"
	elseif stream_type == 0x0F then return "ISO/IEC 13818-7 Audio with ADTS transport syntax"
	elseif stream_type == 0x10 then return "ISO/IEC 14496-2 Visual"
	elseif stream_type == 0x11 then return "ISO/IEC 14496-3 Audio with the LATM transport syntax as defined in ISO/IEC 14496-3"
	elseif stream_type == 0x12 then return "ISO/IEC 14496-1 SL-packetized stream or FlexMux stream carried in PES packets"
	elseif stream_type == 0x13 then return "ISO/IEC 14496-1 SL-packetized stream or FlexMux stream carried in ISO/IEC 14496_sections"
	elseif stream_type == 0x14 then return "ISO/IEC 13818-6 Synchronized Download Protocol"
	elseif stream_type == 0x15 then return "Metadata carried in PES packets"
	elseif stream_type == 0x16 then return "Metadata carried in metadata_sections"
	elseif stream_type == 0x17 then return "Metadata carried in ISO/IEC 13818-6 Data Carousel"
	elseif stream_type == 0x18 then return "Metadata carried in ISO/IEC 13818-6 Object Carousel"
	elseif stream_type == 0x19 then return "Metadata carried in ISO/IEC 13818-6 Synchronized Download Protocol"
	elseif stream_type == 0x1A then return "IPMP stream (defined in ISO/IEC 13818-11, MPEG-2 IPMP)"
	elseif stream_type == 0x1B then return "[H.264]" -- AVC video stream conforming to one or more profiles defined in Annex A of Rec. ITU-T H.264 |"
	                                       --.." ISO/IEC 14496-10 or AVC video sub-bitstream of SVC as defined in 2.1.78 or MVC base view"
	                                       --.." sub-bitstream, as defined in 2.1.85, or AVC video sub-bitstream of MVC, as defined in 2.1.88"
	elseif stream_type == 0x1C then return "ISO/IEC 14496-3 Audio, without using any additional transport syntax, such as DST, ALS and SLS"
	elseif stream_type == 0x1D then return "ISO/IEC 14496-17 Text"
	elseif stream_type == 0x1E then return "Auxiliary video stream as defined in ISO/IEC 23002-3"
	elseif stream_type == 0x1F then return "SVC video sub-bitstream of an AVC video stream conforming to one or more profiles defined in Annex G of Rec. ITU-T H.264 | ISO/IEC 14496-10"
	elseif stream_type == 0x20 then return "MVC video sub-bitstream of an AVC video stream conforming to one or more profiles defined in Annex H of Rec. ITU-T H.264 | ISO/IEC 14496-10"
	elseif stream_type == 0x21 then return "Video stream conforming to one or more profiles as defined in Rec. ITU-T T.800 | ISO/IEC 15444-1"
	elseif stream_type == 0x22 then return "Additional view Rec. ITU-T H.262 | ISO/IEC 13818-2 video stream for service-compatible stereoscopic 3D services (see Notes 3 and 4)"
	elseif stream_type == 0x23 then return "Additional view Rec. ITU-T H.264 | ISO/IEC 14496-10 video stream conforming to one or more profiles defined in Annex A for service-compatible stereoscopic 3D services (see Notes 3 and 4)"
	elseif 0x24 <= stream_type and stream_type <= 0x7E then
		return "Rec. ITU-T H.222.0 | ISO/IEC 13818-1 Reserved"
	elseif stream_type == 0x7F then
		return "IPMP stream"
	elseif 0x80 <= stream_type and stream_type <= 0xFF then
		return "User Private"
	elseif stream_type == 0x81 then
		 return "AC3"
	elseif stream_type == 0xFD then
		 return "ADTS AAC"
	else
		print("unknown stream_type", stream_type)
	end
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
	rbyte("descriptor()",                                   get("program_info_length"))
	
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
		rbyte("descriptor()",                               get("ES_info_length"))
		
		-- 初めて見るPIDなら追加
		local buf = stream:new(1024*1024*3)
		buf:enable_print(false)
	    pes_buf_array[get("elementary_PID")] = buf
		print("", stream_type_to_string(get("stream_type"))..
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
		progress:check()
	
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
		
		if get("payload_unit_start_indicator") == 1 then
			payload(get("PID"))
		end
		
		if get("adaptation_field_control") & 2 == 2 then
			adaptation_field()
		end
		
		if get("adaptation_field_control") & 1 == 1 then
			if  data_byte(target, get("PID"), ts_packet_size - (cur() - begin)) == true then
				if target=="pat" or target=="pmt" then
					return
				end
			end
		end
		
		total = total + (cur()-begin)
	end
end

function data_byte(target, pid, size)
	if target == "pat" then
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
	elseif target == "pmt" then 
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
	elseif target == "pes" then
		if pes_buf_array[pid] ~= nil then
			-- バッファにデータ転送
			tbyte("data_byte", size, pes_buf_array[pid])
			return true
		else
			rbyte("unknown data", size)
			return false
		end
	end
end

function payload(pid)
	local buf = pes_buf_array[pid]
	if  buf ~= nil then
		if buf:get_size() ~= buf:cur() then
			local size, PTS, DTS = pes(buf, pid)
			store_recode(pid, cur(), size, false, PTS, DTS)
			if buf:get_size() ~= buf:cur() then
				buf:rbyte("#unknown remain data", buf:get_size() - buf:cur())
			end
		end
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
	printf("%10d,%10d,%10d,%10.3f,%10.3f,%10.3f", pid, offset, size, PCR/90000, PTS/90000, DTS/90000)
end

function analyze()
	print("analyze PAT")
	seek(0)
	enable_print(false)
	stdout_to_file(false)
	ts(1024*1024, "pat")

	print("analyze PMT")
	seek(0)
	enable_print(false)
	stdout_to_file(false)
	ts(1024*1024, "pmt")

	print("analyze PES")
	seek(0)
	enable_print(false)
	stdout_to_file(false)
	ts(get_size()-200, "pes")
end

open(__stream_path__)
print_status()
analyze()
save_as_csv(__stream_dir__.."out/ts.csv")
print_status()



