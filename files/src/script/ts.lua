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
		rbit("program_clock_reference_base",                33)
		rbit("reserved",                                    6)
		rbit("program_clock_reference_extension",           9)
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
		end
		total = total + 4 
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

function stream_type_to_string(stream_type)
	assert(stream_type)
	if     stream_type == 0x01 then return "MPEG-1 Video"
	elseif stream_type == 0x02 then return "MPEG-2 Video"
	elseif stream_type == 0x03 then return "MPEG-1 Audio"
	elseif stream_type == 0x04 then return "MPEG-2 Audio"
	elseif stream_type == 0x81 then return "AC3"
	elseif stream_type == 0x1B then return "H.264"
	elseif stream_type == 0xF  then return "ADTS AAC"
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
	
	local len = get("section_length") - 4  - 9 - get("program_info_length")
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
		local buf = stream:new(1024*1024)
		buf:enable_print(false)
	    pes_buf_array[get("elementary_PID")] = buf
		print("", stream_type_to_string(get("stream_type")).." = "..hexstr(get("elementary_PID")))

		total = total + get("ES_info_length") + 5
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

function ts(size, target)
	local total = 0
	local no = 0
	local begin
	local buf
	
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
			rbyte("ATS",                                    4)
			-- printf("  ATS = %x(%fsec)", get("ATS"), get("ATS")/90000)
		end

		local ofs = fbyte(0x47, true)
		rbit("syncbyte",                                    8)
		if ofs ~= 0 then
			if ofs < 20 then -- 適当 208バイト
				ts_packet_size = ts_packet_size + ofs
			else
				ts_packet_size = 188
			end
			
			print("# discontinuous syncbyte --> size chagne to "..ts_packet_size)
		end

		rbit("transport_error_indicator",                   1)
		rbit("payload_unit_start_indicator",                1)		
		rbit("transport_priority",                          1)
		rbit("PID",                                         13)
		rbit("transport_scrambling_control",                2)
		rbit("adaptation_field_control",                    2)
		rbit("continuity_counter",                          4)
		
		-- データがあればダンプ
		if get("payload_unit_start_indicator") == 1 then
			buf = pes_buf_array[get("PID")]
			if  buf ~= nil then
				if buf:size() ~= buf:cur() then
					print("#pes payload", buf:size(), buf:cur())
					pes(buf, get("PID"))
					buf:rbyte("#unknown remain data", buf:size() - buf:cur())
				end
			end
		end
		
		if get("adaptation_field_control") & 2 == 2 then
			adaptation_field()
		end
		
		if get("adaptation_field_control") & 1 == 1 then
			if target == "pat" then
				if get("PID") == 0 then
					if get("payload_unit_start_indicator")==1 then
						rbit("pointer_field", 8)
						pat()
						rbyte("stuffing", ts_packet_size - (cur() - begin))

						-- とりあえずPATが見つかったら解析中止
						return
					else
						assert(false, "# unsupported yet")
					end
				else
					rbyte("data_byte", ts_packet_size - (cur() - begin))
				end
			elseif target == "pmt" then 
				if get("PID") == pmt_pid then
					if get("payload_unit_start_indicator")==1 then
						rbit("pointer_field", 8)
						pmt()
						rbyte("stuffing", ts_packet_size - (cur() - begin))
						
						-- とりあえずPMTが見つかったら解析中止
						return
					else
						assert(false, "# unsupported yet")
					end
				else
					rbyte("data_byte", ts_packet_size - (cur() - begin))
				end
			elseif target == "pes" then
				if pes_buf_array[get("PID")] ~= nil then
					-- バッファにデータ転送
					tbyte(pes_buf_array[get("PID")], ts_packet_size - (cur() - begin))
				else
					rbyte("unknown data", ts_packet_size - (cur() - begin))
				end
			end
		end
		
		total = total + (cur()-begin)
	end
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
	ts(file_size()/5, "pes")
	print_table(result)
end

open(__stream_path__)
analyze()



