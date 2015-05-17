-- ts解析
-- ./a.out test.ts

-- ストリーム解析
local ts_packet_size = 188
local psi_check = true
local data = {}

local pid_array = {0}
local pid_infos = {"pat"}
local pid_files = {"pat.pat"}

function ts(size)
	local total = 0
	local begin
	while total < size do
		begin = cur()

		if ts_packet_size == 192 then
			rbyte("ATS",                                    4, data)
			-- printf("  ATS = %x(%fsec)", data["ATS"], data["ATS"]/90000)
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
		rbit("payload_unit_start_indicator",                1,  data)
		rbit("transport_priority",                          1)
		rbit("PID",                                         13, data)
		rbit("transport_scrambling_control",                2)
		-- adaptation_field_control
	    rbit("adaptation_field_present",                    1, data)
	    rbit("data_byte_present",                           1, data)
		rbit("continuity_counter",                          4, data)

		if data["adaptation_field_present"] == 1 then
			adaptation_field()
		end
		
		if data["data_byte_present"] == 1 then
			if psi_check then
				if data["PID"] == 0 then
					if data["payload_unit_start_indicator"]==1 then
						rbit("pointer_field", 8)
						pat()
						rbyte("stuffing", ts_packet_size - (cur() - begin))
					else
						assert(false, "# unsupported yet")
					end
				elseif array_find(pid_array, data["PID"]) ~= false then
					if data["payload_unit_start_indicator"]==1 then
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
				local result = array_find(pid_array, data["PID"])
				if result == false then
					--print("# unknown PID", hex2str(data["PID"]))
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
	rbit("adaptation_field_length",                         8, data)
	if data["adaptation_field_length"] == 0 then
		return
	end
	rbit("discontinuity_indicator",                         1)
	rbit("random_access_indicator",                         1)
	rbit("elementary_stream_priority_indicator",            1)
	rbit("PCR_flag",                                        1, data)
	rbit("OPCR_flag",                                       1, data)
	rbit("splicing_point_flag",                             1, data)
	rbit("transport_private_data_flag",                     1, data)
	rbit("adaptation_field_extension_flag",                 1, data)

	if data["PCR_flag"] == 1 then
		rbit("program_clock_reference_base",                33)
		rbit("reserved",                                    6)
		rbit("program_clock_reference_extension",           9)
	end
	if data["OPCR_flag"] == 1 then
		rbit("original_program_clock_reference_base",       33)
		rbit("reserved",                                    6)
		rbit("original_program_clock_reference_extension",  9)
	end
	if data["splicing_point_flag"] == 1 then
		rbit("splice_countdown",                            8)
	end
	if data["transport_private_data_flag"] == 1 then
		rbit("transport_private_data_length",               8, data)
		rstr("private_data_byte",                           data["transport_private_data_length"])
	end
	if data["adaptation_field_extension_flag"] == 1 then
		local begin = cur()
	    rbit("adaptation_field_extension_length",           8, data)
	    rbit("ltw_flag",                                    1)
	    rbit("piecewise_rate_flag",                         1)
	    rbit("seamless_splice_flag",                        1)
	    rbit("reserved",                                    5)
	    
		if data["ltw_flag"] == 1 then
			rbit("ltw_valid_flag",                          1)
			rbit("ltw_offset",                              15)
		end
		
		if data["piecewise_rate_flag"] == 1 then
	        rbit("reserved",                                2)
	        rbit("piecewise_rate",                          22)
		end
		
		if data["seamless_splice_flag"] == 1 then
		    rbit("splice_type",                             4)
		    rbit("DTS_next_AU[32..30]",                     3)
		    rbit("marker_bit",                              1)
		    rbit("DTS_next_AU[29..15]",                     15)
		    rbit("marker_bit",                              1)
		    rbit("DTS_next_AU[14..0]",                      15)
		    rbit("marker_bit",                              1)
	    end

		rbyte("reserved", data["adaptation_field_extension_length"] + 1 - (cur()-begin))
	end

	rbyte("stuffing_byte", data["adaptation_field_length"] + 1 - (cur() - begin))
end

function pat()
--print("PAT")
	local begin = cur()
	rbit("table_id",                                        8)
	rbit("section_syntax_indicator",                        1)
	rbit("'0'",                                             1)
	rbit("reserved",                                        2)
	rbit("section_length",                                  12, data)
	rbit("transport_stream_id",                             16)
	rbit("reserved",                                        2)
	rbit("version_number",                                  5)
	rbit("current_next_indicator",                          1)
	rbit("section_number",                                  8)
	rbit("last_section_number",                             8)

	local len = data["section_length"] - 5 - 4
	local total = 0
	while total < len do
		rbit("program_number",                              16, data)
		rbit("reserved",                                    3)
		if data["program_number"] == 0 then
		    rbit("network_PID",                             13)
		else
		    rbit("program_map_PID",                         13, data)
		    
		    -- 初めて見るPIDなら追加
		    if array_find(pid_array, data["program_map_PID"]) == false then
			    table.insert(pid_infos, "PMT"..#pid_infos.."="..hex2str(data["program_map_PID"]))
				table.insert(pid_array, data["program_map_PID"])
		  		table.insert(pid_files, "pid"..string.format("%x", data["program_map_PID"])..".pmt")
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
	rbit("section_length",                                  12, data)
	rbit("program_number",                                  16)
	rbit("reserved",                                        2) 
	rbit("version_number",                                  5) 
	rbit("current_next_indicator",                          1) 
	rbit("section_number",                                  8) 
	rbit("last_section_number",                             8) 
	rbit("reserved",                                        3) 
	rbit("PCR_PID",                                         13)
	rbit("reserved",                                        4) 
	rbit("program_info_length",                             12, data)
	rbyte("descriptor()",                                   data["program_info_length"])
	
	local len = data["section_length"]  - 4  - 9 - data["program_info_length"]
	local total = 0
	local num_es = 0
	while total < len do
		rbit("stream_type",                                 8, data)
		rbit("reserved",                                    3)
		rbit("elementary_PID",                              13, data)
		rbit("reserved",                                    4)
		rbit("ES_info_length",                              12, data)
		rbyte("descriptor()",                               data["ES_info_length"])
		
		-- 初めて見るPIDなら追加
	    if array_find(pid_array, data["elementary_PID"]) == false then
			table.insert(pid_infos, stream_type_to_string(data["stream_type"]).."="..hex2str(data["elementary_PID"]))
		    table.insert(pid_array, data["elementary_PID"])
		   	table.insert(pid_files, "pid"..string.format("%x", data["elementary_PID"])..".pes")
		end

		total = total + data["ES_info_length"] + 5
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

-- ファイルオープン＆初期化＆解析
local ext = string.gsub(__file_name__, ".*(%..*)", "%1")
if ext == ".tts"
or ext == ".m2ts" then
	ts_packet_size = 192
else
	ts_packet_size = 188
end

stream = open_stream(__file_name__)
print_on(false)

-- PAT/PMT解析
-- 最大1MB見る
psi_check = true
ts(1024*1024)
for i=1, #pid_infos do
	print(hex2str(pid_array[i]), pid_infos[i], pid_files[i])
end

-- PESファイル抽出
psi_check = false
seek(0)
ts(file_size() - 200) -- 解析開始、後半は200byte捨てる

-- PES解析 1, 2はPAT/PMTなので無視
for i=3, #pid_files do
	__file_name__  = pid_files[i]
	print(__file_name__)
	dofile("script/pes.lua") -- PES解析は別ファイル
end
