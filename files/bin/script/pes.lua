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

function pes(buf, pid)
	local begin = buf:cur()
	local PTS = false
	local DTS = false
	local start_code
	progress:check()
	
    buf:fstr("00 00 01", true)
    start_code = lbyte(4)

	buf:cbit("packet_start_code_prefix",                                    24, 1)
	buf:rbit("stream_id",                                                   8)
	buf:rbit("PES_packet_length",                                           16)
	
	if buf:get("PES_packet_length") == 0 then
		no_packet_length = true
	end
	
	-- H.262
	if  buf:get("stream_id") < 0xB9 then
		-- ES data
		return cur() - begin 
	end
	
	if  buf:get("stream_id") ~= program_stream_map
	and buf:get("stream_id") ~= padding_stream
	and buf:get("stream_id") ~= private_stream_2
	and buf:get("stream_id") ~= ECM_stream
	and buf:get("stream_id") ~= EMM_stream
	and buf:get("stream_id") ~= program_stream_directory
	and buf:get("stream_id") ~= ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	and buf:get("stream_id") ~= ITU_T_Rec_H_222_1_type_E then
	    buf:rbit("'10'",                                                    2)
	    buf:rbit("PES_scrambling_control",                                  2)
	    buf:rbit("PES_priority",                                            1)
	    buf:rbit("data_alignment_indicator",                                1)
	    buf:rbit("copyright",                                               1)
	    buf:rbit("original_or_copy",                                        1)
	    buf:rbit("PTS_DTS_flags",                                           2)
	    buf:rbit("ESCR_flag",                                               1)
	    buf:rbit("ES_rate_flag",                                            1)
	    buf:rbit("DSM_trick_mode_flag",                                     1)
	    buf:rbit("additional_copy_info_flag",                               1)
	    buf:rbit("PES_CRC_flag",                                            1)
	    buf:rbit("PES_extension_flag",                                      1)
	    buf:rbit("PES_header_data_length",                                  8)
	    if buf:get("PTS_DTS_flags") & 2 == 2 then
	        buf:rbit("’0010’",                                            4)
	        buf:rbit("PTS [32..30]",                                        3)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("PTS [29..15]",                                        15)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("PTS [14..0]",                                         15)
	        buf:rbit("marker_bit",                                          1)
	        
		    -- PTS値を計算
			PTS = buf:get("PTS [32..30]")*0x40000000
				+ buf:get("PTS [29..15]")*0x8000
				+ buf:get("PTS [14..0]")
		    -- printf("# PTS=0x%09x (%10.3f sec)", PTS, PTS/90000)
	    end
	    if buf:get("PTS_DTS_flags") & 1 == 1 then
	        buf:rbit("’0001’",                                            4)
	        buf:rbit("DTS [32..30]",                                        3)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("DTS [29..15]",                                        15)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("DTS [14..0]",                                         15)
	        buf:rbit("marker_bit",                                          1)

		    -- DTS値を計算
			DTS = buf:get("DTS [32..30]")*0x40000000
				+ buf:get("DTS [29..15]")*0x8000
				+ buf:get("DTS [14..0]")
		    -- printf("# DTS=0x%09x (%10.3f sec)", DTS, DTS/90000)
	    end
   	    if buf:get("ESCR_flag") == 1 then
	        buf:rbit("reserved",                                            2)
	        buf:rbit("ESCR_base[32..30]",                                   3)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("ESCR_base[29..15]",                                   15)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("ESCR_base[14..0]",                                    15)
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("ESCR_extension",                                      9)
	        buf:rbit("marker_bit",                                          1)
	    end
   	    if buf:get("ES_rate_flag") == 1 then
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("ES_rate",                                             22)
	        buf:rbit("marker_bit",                                          1)
	    end
   	    if buf:get("DSM_trick_mode_flag") == 1 then
	        buf:rbit("trick_mode_control",                                  3)
			if buf:get("trick_mode_control") == fast_forward then
				buf:rbit("field_id",                                        2)
				buf:rbit("intra_slice_refresh",                             1)
				buf:rbit("frequency_truncation",                            2)
			elseif buf:get("trick_mode_control") == slow_motion then
				buf:rbit("rep_cntrl",                                       5)
			elseif buf:get("trick_mode_control") == freeze_frame then
				buf:rbit("field_id",                                        2)
				buf:rbit("reserved",                                        3)
			elseif buf:get("trick_mode_control") == fast_reverse then 
				buf:rbit("field_id",                                        2)
				buf:rbit("intra_slice_refresh",                             1)
				buf:rbit("frequency_truncation",                            2)
			elseif buf:get("trick_mode_control") == slow_reverse then
				buf:rbit("rep_cntrl",                                       2)
			else
				buf:rbit("reserved",                                        5)
			end
	    end
   	    if buf:get("additional_copy_info_flag") == 1 then
	        buf:rbit("marker_bit",                                          1)
	        buf:rbit("additional_copy_info",                                7)
	    end
   	    if buf:get("PES_CRC_flag") == 1 then
	        buf:rbit("previous_PES_packet_CRC",                             16)
	    end
   	    if buf:get("PES_extension_flag") == 1 then
	        buf:rbit("PES_private_data_flag",                               1)
	        buf:rbit("pack_header_field_flag",                              1)
	        buf:rbit("program_packet_sequence_counter_flag",                1)
	        buf:rbit("P-STD_buffer_flag",                                   1)
	        buf:rbit("reserved",                                            3)
	        buf:rbit("PES_extension_flag_2",                                1)
   	  		if buf:get("PES_private_data_flag") == 1 then
	            buf:rbit("PES_private_data",                                128)
	        end
   	  		if buf:get("pack_header_field_flag") == 1 then
	            buf:rbit("pack_field_length",                               8)
	            buf:rbit("pack_header()",                                   buf:get("pack_field_length"))
	        end
   	  		if buf:get("program_packet_sequence_counter_flag") == 1 then
	            buf:rbit("marker_bit",                                      1)
	            buf:rbit("program_packet_sequence_counter",                 7)
	            buf:rbit("marker_bit",                                      1)
	            buf:rbit("MPEG1_MPEG2_identifier",                          1)
	            buf:rbit("original_stuff_length",                           6)
	        end
   	  		if buf:get("STD_buffer_flag") == 1 then
	            buf:rbit("'01'",                                            2)
	            buf:rbit("P-STD_buffer_scale",                              1)
	            buf:rbit("P-STD_buffer_size",                               13)
	        end
   	  		if buf:get("PES_extension_flag_2") == 1 then
	            buf:rbit("marker_bit",                                      1)
	            buf:rbit("PES_extension_field_length",                      7)
 	            buf:rbyte("reserved",                                       buf:get("PES_extension_field_length"))
	        end
	    end
	    
	    --for i = 0; i < N1; i++) do
	    --    buf:rbit("stuffing_byte",                                     N1) -- 0xFFデータ、デコーダがすてるはずでここではパースしない
	    --end

	    local N = buf:get("PES_packet_length") - (cur() - begin) + 6
        if no_packet_length then
			buf:seek(buf:cur()+4)
			local ofs = buf:fstr(hex2str(start_code), false)
			buf:seek(buf:cur()-4)
	        buf:tbyte("PES_packet_data_byte",
	        	__stream_dir__.."out/pid"..hexstr(pid)..".es", ofs + 4)
        else
	        buf:tbyte("PES_packet_data_byte",
	        	__stream_dir__.."out/pid"..hexstr(pid)..".es", N)
        end
        
	elseif buf:get("stream_id") == program_stream_map
	or     buf:get("stream_id") == private_stream_2
	or     buf:get("stream_id") == ECM_stream
	or     buf:get("stream_id") == EMM_stream
	or     buf:get("stream_id") == program_stream_directory
	or     buf:get("stream_id") == ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	or     buf:get("stream_id") == ITU_T_Rec_H_222_1_type_E then
	    buf:tbyte(__stream_dir__.."out/pid.es",         buf:get("PES_packet_length"))
	elseif ( stream_id == padding_stream) then
        buf:rbyte("padding_byte",                                        buf:get("PES_packet_length"))
	end

	-- return buf:get("PES_packet_length")
	return buf:cur() - begin, PTS, DTS
end

function pes_stream(size)
    fstr("00 00 01")
    start_code = lbyte(4)
    
	local result = {};
    result["PTS"..__pid__]={}
    result["DTS"..__pid__]={}

	local total_size = 0;
	while total_size < size do
		total_size = total_size + pes(result)
	end
	
	return result
end

-- ファイルオープン＆初期化＆解析
--__pid__ = __pid__ or 0
--
--open(__stream_path__)
--enable_print(false)
--stdout_to_file(false)
--start_thread(pes_stream, file_size())

