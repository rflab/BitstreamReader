-- ts解析
-- ./a.out test.ts

-- ストリーム解析
local ts_packet_size = 188
local psi_check = true

local pid_array = {0}
local pid_infos = {"pat"}
local pid_files = {"out/pat.pat"}

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
			    table.insert(pid_infos, "PMT"..#pid_infos.."="..format_hex(get("program_map_PID")))
				table.insert(pid_array, get("program_map_PID"))
		  		table.insert(pid_files, __stream_dir__.."out/pid"..format_hex(get("program_map_PID"))..".pmt")
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
			table.insert(pid_infos, stream_type_to_string(get("stream_type")).."="..format_hex(get("elementary_PID")))
			
		    table.insert(pid_array, get("elementary_PID"))
		   	table.insert(pid_files, __stream_dir__.."out/pid"..format_hex(get("elementary_PID"))..".pes")
		end

		total = total + get("ES_info_length") + 5
	end
	rbit("CRC_32",                                          32)
	
	return cur() - begin
end

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
		begin = cur()
		progress:check()
	
		if ts_packet_size == 192 then
			rbyte("ATS",                                    4)
			-- printf("  ATS = %x(%fsec)", get("ATS"), get("ATS")/90000)
		end
		
		local ofs = fbyte(0x47, true)
		rbit("syncbyte",                                    8)
		if ofs ~= 0 then
			print("# discontinuous syncbyte", ts_packet_size, ofs, format_hex(cur()))
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
		rbit("adaptation_field_control",                    2)
		rbit("continuity_counter",                          4)

		if get("adaptation_field_control") & 2 == 2 then
			adaptation_field()
		end
		
		if get("adaptation_field_control") & 1 == 1 then
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
					tbyte(pid_files[result], ts_packet_size - (cur() - begin))
				end
			end
		end
		
		total = total + (cur()-begin)
	end
end

local no_packet_length = false 
local start_code = pat2str("00 00 01 C0")


-- 各種タグ
local program_stream_map = 0xbc;
local private_stream_1   = 0xbd;
local padding_stream     = 0xbe;
local private_stream_2   = 0xbf;
local ISO_IEC_13818_3_or_ISO_IEC_11172_3_audio_stream_number_x_xxxx = 0xc0;
local ITU_T_Rec_H_262_ISO_IEC_13818_2_or_ISO_IEC_11172_2_video_stream_number_xxxx = 0xe0;
local ECM_stream = 0xf0;
local EMM_stream = 0xf1; 
local ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream = 0xf2;
local ISO_IEC_13522_stream = 0xf3;
local ITU_T_Rec_H_222_1_type_A = 0xf4;
local ITU_T_Rec_H_222_1_type_B = 0xf5;
local ITU_T_Rec_H_222_1_type_C = 0xf6;
local ITU_T_Rec_H_222_1_type_D = 0xf7;
local ITU_T_Rec_H_222_1_type_E = 0xf8;
local ancillary_stream = 0xf9;
local program_stream_directory = 0xff;
local fast_forward = 0x0;
local slow_motion  = 0x1;
local freeze_frame = 0x2;
local fast_reverse = 0x3;
local slow_reverse = 0x4;

function pes(fifo)
	local begin = fifo:cur()
	
    --fifo:nstr("00 00 01", true)
	--fifo:rbit("packet_start_code_prefix",                                  24)
	fifo:rbit("packet_start_code",                                           32)
	fifo:rbit("stream_id",                                                   8,  data)
	fifo:rbit("PES_packet_length",                                           16, data)
	
	if get("PES_packet_length") == 0 then
		no_packet_length = true
	end
	
	-- H.262
	if  get("stream_id") < 0xB9 then
		-- ES data
		return cur() - begin 
	end
	
	if  get("stream_id") ~= program_stream_map
	and get("stream_id") ~= padding_stream
	and get("stream_id") ~= private_stream_2
	and get("stream_id") ~= ECM_stream
	and get("stream_id") ~= EMM_stream
	and get("stream_id") ~= program_stream_directory
	and get("stream_id") ~= ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	and get("stream_id") ~= ITU_T_Rec_H_222_1_type_E then
	    rbit("'10'",                                                    2)
	    rbit("PES_scrambling_control",                                  2)
	    rbit("PES_priority",                                            1)
	    rbit("data_alignment_indicator",                                1)
	    rbit("copyright",                                               1)
	    rbit("original_or_copy",                                        1)
	    --PTS_DTS_flags
	    rbit("PTS_flag",                                                1, data)
	    rbit("DTS_flag",                                                1, data)
	    rbit("ESCR_flag",                                               1, data)
	    rbit("ES_rate_flag",                                            1, data)
	    rbit("DSM_trick_mode_flag",                                     1, data)
	    rbit("additional_copy_info_flag",                               1, data)
	    rbit("PES_CRC_flag",                                            1, data)
	    rbit("PES_extension_flag",                                      1, data)
	    rbit("PES_header_data_length",                                  8, data)
	    if get("PTS_flag") == 1 then
	        rbit("’0010’",                                            4)
	        rbit("PTS [32..30]",                                        3,  data)
	        rbit("marker_bit",                                          1)
	        rbit("PTS [29..15]",                                        15, data)
	        rbit("marker_bit",                                          1)
	        rbit("PTS [14..0]",                                         15, data)
	        rbit("marker_bit",                                          1)
	        
		    -- PTS値を計算
			local PTS = get("PTS [32..30]")*0x40000000 + get("PTS [29..15]")*0x8000 + get("PTS [14..0]")
		    --printf("# PTS=0x%09x (%10.3f sec)", PTS, PTS/90000)

			store(__stream_name__.."PTS", PTS/90000)

	    end
	    if get("DTS_flag") == 1 then
	        rbit("’0001’",                                            4)
	        rbit("DTS [32..30]",                                        3,  data)
	        rbit("marker_bit",                                          1)
	        rbit("DTS [29..15]",                                        15, data)
	        rbit("marker_bit",                                          1)
	        rbit("DTS [14..0]",                                         15, data)
	        rbit("marker_bit",                                          1)

		    -- DTS値を計算
			local DTS = get("DTS [32..30]")*0x40000000 + get("DTS [29..15]")*0x8000 + get("DTS [14..0]")
		    --printf("# DTS=0x%09x (%10.3f sec)", DTS, DTS/90000)

			store(__stream_name__.."DTS", DTS/90000)
	    end
   	    if get("ESCR_flag") == 1 then
	        rbit("reserved",                                            2)
	        rbit("ESCR_base[32..30]",                                   3)
	        rbit("marker_bit",                                          1)
	        rbit("ESCR_base[29..15]",                                   15)
	        rbit("marker_bit",                                          1)
	        rbit("ESCR_base[14..0]",                                    15)
	        rbit("marker_bit",                                          1)
	        rbit("ESCR_extension",                                      9)
	        rbit("marker_bit",                                          1)
	    end
   	    if get("ES_rate_flag") == 1 then
	        rbit("marker_bit",                                          1)
	        rbit("ES_rate",                                             22)
	        rbit("marker_bit",                                          1)
	    end
   	    if get("DSM_trick_mode_flag") == 1 then
	        rbit("trick_mode_control",                                  3, data)
			if get("trick_mode_control") == fast_forward then
				rbit("field_id",                                        2)
				rbit("intra_slice_refresh",                             1)
				rbit("frequency_truncation",                            2)
			elseif get("trick_mode_control") == slow_motion then
				rbit("rep_cntrl",                                       5)
			elseif get("trick_mode_control") == freeze_frame then
				rbit("field_id",                                        2)
				rbit("reserved",                                        3)
			elseif get("trick_mode_control") == fast_reverse then 
				rbit("field_id",                                        2)
				rbit("intra_slice_refresh",                             1)
				rbit("frequency_truncation",                            2)
			elseif get("trick_mode_control") == slow_reverse then
				rbit("rep_cntrl",                                       2)
			else
				rbit("reserved",                                        5)
			end
	    end
   	    if get("additional_copy_info_flag") == 1 then
	        rbit("marker_bit",                                          1)
	        rbit("additional_copy_info",                                7)
	    end
   	    if get("PES_CRC_flag") == 1 then
	        rbit("previous_PES_packet_CRC",                             16)
	    end
   	    if get("PES_extension_flag") == 1 then
	        rbit("PES_private_data_flag",                               1)
	        rbit("pack_header_field_flag",                              1)
	        rbit("program_packet_sequence_counter_flag",                1)
	        rbit("P-STD_buffer_flag",                                   1)
	        rbit("reserved",                                            3)
	        rbit("PES_extension_flag_2",                                1)
   	  		if get("PES_private_data_flag") == 1 then
	            rbit("PES_private_data",                                128)
	        end
   	  		if get("pack_header_field_flag") == 1 then
	            rbit("pack_field_length",                               8, data)
	            rbit("pack_header()",                                   get("pack_field_length"))
	        end
   	  		if get("program_packet_sequence_counter_flag") == 1 then
	            rbit("marker_bit",                                      1)
	            rbit("program_packet_sequence_counter",                 7)
	            rbit("marker_bit",                                      1)
	            rbit("MPEG1_MPEG2_identifier",                          1)
	            rbit("original_stuff_length",                           6)
	        end
   	  		if get("STD_buffer_flag") == 1 then
	            rbit("'01'",                                            2)
	            rbit("P-STD_buffer_scale",                              1)
	            rbit("P-STD_buffer_size",                               13)
	        end
   	  		if get("PES_extension_flag_2") == 1 then
	            rbit("marker_bit",                                      1)
	            rbit("PES_extension_field_length",                      7, data)
 	            rbyte("reserved",                                       get("PES_extension_field_length"))
	        end
	    end
	    
	    --for i = 0; i < N1; i++) do
	    --    rbit("stuffing_byte",                                     N1) -- 0xFFデータ、デコーダがすてるはずでここではパースしない
	    --end

	    local N = get("PES_packet_length") - (cur() - begin) + 6
        if no_packet_length then
			seek(cur()+4)
			local ofs = fstr(hex2str(start_code), false)
			seek(cur()-4)
	        tbyte(__stream_dir__.."out/PES_packet_data_byte_"..format_hex(__pid__)..".es", ofs + 4)
        else
	        tbyte(__stream_dir__.."out/PES_packet_data_byte_"..format_hex(__pid__)..".es", N)
        end
        
	elseif get("stream_id") == program_stream_map
	or     get("stream_id") == private_stream_2
	or     get("stream_id") == ECM_stream
	or     get("stream_id") == EMM_stream
	or     get("stream_id") == program_stream_directory
	or     get("stream_id") == ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	or     get("stream_id") == ITU_T_Rec_H_222_1_type_E then
	    tbyte(__stream_dir__.."out/PES_packet_data_byte.es",         get("PES_packet_length"))
	elseif ( stream_id == padding_stream) then
        rbyte("padding_byte",                                        get("PES_packet_length"))
	end

	-- return get("PES_packet_length")
	return cur() - begin 
end

-- PAT/PMT解析
psi_check = true
open(__stream_path__)
enable_print(false)
stdout_to_file(false)
start_thread(ts, 1024*1024)

-- PMT結果表示
for i=1, #pid_infos do
	print(format_hex(pid_array[i]), pid_infos[i], pid_files[i])
end

-- PESファイル抽出
psi_check = false
seek(0)
enable_print(false)
stdout_to_file(false)
start_thread(ts, file_size())

save_as_csv("out/ts.csv")

-- PES解析 1, 2はPAT/PMTなので無視
for i=3, #pid_files do	
	__stream_path__ = pid_files[i];
	__pid__ = pid_array[i]
	
	dofile(__exec_dir__.."script/pes.lua")
end
