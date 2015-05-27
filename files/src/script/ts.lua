-- ts解析
-- ./a.out test.ts

-- ストリーム解析
local ts_packet_size = 188
local psi_check = true

local pid_array = {0}
local pid_infos = {"pat"}
local pid_files = {"out/pat.pat"}


function ts(size)
	local total = 0
	local begin
	
	-- 初期TSパケット長
	if __stream_ext__ == ".tts"
	or __stream_ext__ == ".m2ts" then
		ts_packet_size = 192
	else
		ts_packet_size = 188
	end

	while total < size do
			
		progress:check()
		
		begin = cur()
	
		if ts_packet_size == 192 then
			rbyte("ATS",                                    4)
			-- printf("  ATS = %x(%fsec)", get("ATS"), get("ATS")/90000)
		end
		
		local ofs = sbyte(0x47)
		rbit("syncbyte",                                    8)
		if ofs ~= 0 then
			print("# discontinuous syncbyte", ts_packet_size, ofs, hex2str(cur()))
			if ofs < 20 then -- 適当 208バイト
				ts_packet_size = ts_packet_size + ofs
			else
				ts_packet_size = 188
			end
		end

		rbit("transport_error_indicator",                   1)
		rbit("payload_unit_start_indicator",                1)
		rbit("transport_priority",                          1)
		rbit("PID",                                         13)
		rbit("transport_scrambling_control",                2)
		-- adaptation_field_control
	    rbit("adaptation_field_present",                    1)
	    rbit("data_byte_present",                           1)
		rbit("continuity_counter",                          4)

		if get("adaptation_field_present") == 1 then
			adaptation_field()
		end
		
		if get("data_byte_present") == 1 then
			if psi_check then
				if get("PID") == 0 then
					if get("payload_unit_start_indicator")==1 then
						rbit("pointer_field", 8)
						pat()
						rbyte("stuffing", ts_packet_size - (cur() - begin))
					else
						assert(false, "# unsupported yet")
					end
				elseif find(pid_array, get("PID")) ~= false then
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
			else
				local result = find(pid_array, get("PID"))
				if result == false then
					rbyte("unknown data", ts_packet_size - (cur() - begin))
				else		
					wbyte(pid_files[result], ts_packet_size - (cur() - begin))
				end
			end
		end
		
		total = total + (cur()-begin)
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
		rbit("transport_private_data_length",               8)
		rstr("private_data_byte",                           get("transport_private_data_length"))
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

	rbyte("stuffing_byte", get("adaptation_field_length") + 1 - (cur() - begin))
end

function pat()
--print("PAT")
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
		    if find(pid_array, get("program_map_PID")) == false then
			    table.insert(pid_infos, "PMT"..#pid_infos.."="..hex2str(get("program_map_PID")))
				table.insert(pid_array, get("program_map_PID"))
		  		table.insert(pid_files, __stream_dir__.."out/pid"..hex2str(get("program_map_PID"))..".pmt")
			end
		end
		total = total + 4 
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

function stream_type_to_string(stream_type)
	assert(stream_type)
	if     stream_type == 0x01 then return "MPEG-1 Video "
	elseif stream_type == 0x02 then return "MPEG-2 Video "
	elseif stream_type == 0x03 then return "MPEG-1 Audio "
	elseif stream_type == 0x04 then return "MPEG-2 Audio "
	elseif stream_type == 0x81 then return "AC3 "
	elseif stream_type == 0x1B then return "H.264 "
	elseif stream_type == 0xF  then return "ADTS AAC "
	else
		print("unknown stream_type", stream_type)
	end
end

function pmt()
--print("PMT")
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
	    if find(pid_array, get("elementary_PID")) == false then
			table.insert(pid_infos, stream_type_to_string(get("stream_type")).."="..hex2str(get("elementary_PID")))
			
		    table.insert(pid_array, get("elementary_PID"))
		   	table.insert(pid_files, __stream_dir__.."out/pid"..hex2str(get("elementary_PID"))..".pes")
		end

		total = total + get("ES_info_length") + 5
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

open(__stream_path__)
enable_print(false)
stdout_to_file(false)


-- PAT/PMT解析
psi_check = true
ts(1024*1024)
for i=1, #pid_infos do
	print(hex2str(pid_array[i]), pid_infos[i], pid_files[i])
end

-- PESファイル抽出
psi_check = false
seek(0)
ts(file_size() - 200) -- 解析開始、後半は200byte捨てる
save_as_csv("out/ts.csv")

-- PES解析 1, 2はPAT/PMTなので無視
for i=3, #pid_files do	
	__stream_path__ = pid_files[i];
	__pid__ = pid_array[i]
	
	dofile(__exec_dir__.."script/pes.lua")
end
