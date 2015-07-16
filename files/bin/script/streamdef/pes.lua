-- PES解析
-- VideoPESは規格上PES_packet_length=0が許可されているので特別扱いする
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

function pes(pid, size, out_file_name)
	local begin = cur()
	local PTS = false
	local DTS = false
	local start_code
	local ofs
	
	ofs = fstr("00 00 01", true)
	assert(ofs == 0)
	start_code = lbyte(4)
 
	cbit("packet_start_code_prefix",                                    24, 1)
	rbit("stream_id",                                                   8)
	rbit("PES_packet_length",                                           16)
	
	if get("PES_packet_length") == 0 then
		no_packet_length = true
	end
		
	if  get("stream_id") ~= program_stream_map
	and get("stream_id") ~= padding_stream
	and get("stream_id") ~= private_stream_2
	and get("stream_id") ~= ECM_stream
	and get("stream_id") ~= EMM_stream
	and get("stream_id") ~= program_stream_directory
	and get("stream_id") ~= ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	and get("stream_id") ~= ITU_T_Rec_H_222_1_type_E then
	    cbit("'10'",                                                    2, 2)
	    rbit("PES_scrambling_control",                                  2)
	    rbit("PES_priority",                                            1)
	    rbit("data_alignment_indicator",                                1)
	    rbit("copyright",                                               1)
	    rbit("original_or_copy",                                        1)
	    rbit("PTS_DTS_flags",                                           2)
	    rbit("ESCR_flag",                                               1)
	    rbit("ES_rate_flag",                                            1)
	    rbit("DSM_trick_mode_flag",                                     1)
	    rbit("additional_copy_info_flag",                               1)
	    rbit("PES_CRC_flag",                                            1)
	    rbit("PES_extension_flag",                                      1)
	    rbit("PES_header_data_length",                                  8)
	    if get("PTS_DTS_flags") & 2 == 2 then
	        rbit("’0010’",                                            4)
	        rbit("PTS [32..30]",                                        3)
	        rbit("marker_bit",                                          1)
	        rbit("PTS [29..15]",                                        15)
	        rbit("marker_bit",                                          1)
	        rbit("PTS [14..0]",                                         15)
	        rbit("marker_bit",                                          1)
	        
		    -- PTS値を計算
			PTS = get("PTS [32..30]")*0x40000000
				+ get("PTS [29..15]")*0x8000
				+ get("PTS [14..0]")
		    -- printf("# PTS=0x%09x (%10.3f sec)", PTS, PTS/90000)
	    end
	    if get("PTS_DTS_flags") & 1 == 1 then
	        rbit("’0001’",                                            4)
	        rbit("DTS [32..30]",                                        3)
	        rbit("marker_bit",                                          1)
	        rbit("DTS [29..15]",                                        15)
	        rbit("marker_bit",                                          1)
	        rbit("DTS [14..0]",                                         15)
	        rbit("marker_bit",                                          1)

		    -- DTS値を計算
			DTS = get("DTS [32..30]")*0x40000000
				+ get("DTS [29..15]")*0x8000
				+ get("DTS [14..0]")
		    -- printf("# DTS=0x%09x (%10.3f sec)", DTS, DTS/90000)
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
	        rbit("trick_mode_control",                                  3)
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
	            rbit("pack_field_length",                               8)
	            rbit("pack_header()",                                   get("pack_field_length"))
	        end
   	  		if get("program_packet_sequence_counter_flag") == 1 then
	            rbit("marker_bit",                                      1)
	            rbit("program_packet_sequence_counter",                 7)
	            rbit("marker_bit",                                      1)
	            rbit("MPEG1_MPEG2_identifier",                          1)
	            rbit("original_stuff_length",                           6)
	        end
   	  		if get("P-STD_buffer_flag") == 1 then
	            rbit("'01'",                                            2)
	            rbit("P-STD_buffer_scale",                              1)
	            rbit("P-STD_buffer_size",                               13)
	        end
   	  		if get("PES_extension_flag_2") == 1 then
	            rbit("marker_bit",                                      1)
	            rbit("PES_extension_field_length",                      7)
 	            rbyte("reserved",                                       get("PES_extension_field_length"))
	        end
	    end
	    
	    --for i = 0; i < N1; i++) do
	    --    rbit("stuffing_byte",                                     N1) -- 0xFFデータ、デコーダがすてるはずでここではパースしない
	    --end

	    local N = get("PES_packet_length") - (cur() - begin) + 6
        if no_packet_length then
        	if size ~= nil then
        		assert(size==(get_size()-begin))
		        tbyte("PES_packet_data_byte", size - (cur()-begin), out_file_name)
        	else
				seek(cur()+4)
				local ofs = fstr(val2str(start_code), false)
				seek(cur()-4)
				if ofs ~= false then
			        tbyte("PES_packet_data_byte", ofs + 4, out_file_name)
				else
			        tbyte("PES_packet_data_byte", get_size() - cur(), out_file_name)
				end
			end
        else
	        tbyte("PES_packet_data_byte", N, out_file_name)
        end
        
	elseif get("stream_id") == program_stream_map
	or     get("stream_id") == private_stream_2
	or     get("stream_id") == ECM_stream
	or     get("stream_id") == EMM_stream
	or     get("stream_id") == program_stream_directory
	or     get("stream_id") == ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	or     get("stream_id") == ITU_T_Rec_H_222_1_type_E then
	    tbyte("PES_packet_data_byte", get("PES_packet_length"), out_file_name)
	elseif ( stream_id == padding_stream) then
        rbyte("padding_byte", get("PES_packet_length"))
	end

	return cur() - begin, PTS, DTS
end

function pes_stream(size)
    fstr("00 00 01")
    start_code = lbyte(4)

	local total_size = 0;
	while total_size < size do
	    if fstr("00 00 01", false, 0x10000) == get_size()-cur() then
	    	break
	    end
		total_size = total_size + pes(0xffff, nil, __out_dir__.."out.es")
	end
end

if __stream_ext__ == ".pes" then
	open(__stream_path__)
	enable_print(__default_enable_print__)
	pes_stream(get_size() - 10*1024)
end

