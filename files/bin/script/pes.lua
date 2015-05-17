-- PES解析
data = {}

-- VideoPESは規格上PES_packet_length=0が許可されているので特別扱いする
local no_packet_length = false 

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

function pes()
	--print("PES")	
	local begin = cur()
    sstr("00 00 01")
	rbit("packet_start_code_prefix",                                    24)
	rbit("stream_id",                                                   8,  data)
	rbit("PES_packet_length",                                           16, data)
	
	if data["PES_packet_length"] == 0 then
		no_packet_length = true
	end
	
	-- H.262
	if  data["stream_id"] < 0xB9 then
		-- ES data
		return cur() - begin 
	end
	
	if  data["stream_id"] ~= program_stream_map
	and data["stream_id"] ~= padding_stream
	and data["stream_id"] ~= private_stream_2
	and data["stream_id"] ~= ECM_stream
	and data["stream_id"] ~= EMM_stream
	and data["stream_id"] ~= program_stream_directory
	and data["stream_id"] ~= ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	and data["stream_id"] ~= ITU_T_Rec_H_222_1_type_E then
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
	    if data["PTS_flag"] == 1 then
	        rbit("’0010’",                                            4)
	        rbit("PTS [32..30]",                                        3,  data)
	        rbit("marker_bit",                                          1)
	        rbit("PTS [29..15]",                                        15, data)
	        rbit("marker_bit",                                          1)
	        rbit("PTS [14..0]",                                         15, data)
	        rbit("marker_bit",                                          1)
	        
		    -- PTS値を計算
			local PTS = data["PTS [32..30]"]*0x40000000 + data["PTS [29..15]"]*0x8000 + data["PTS [14..0]"]
		    printf("# PTS=0x%09x (%10.3f sec)", PTS, PTS/90000)

	    end
	    if data["DTS_flag"] == 1 then
	        rbit("’0001’",                                            4)
	        rbit("DTS [32..30]",                                        3,  data)
	        rbit("marker_bit",                                          1)
	        rbit("DTS [29..15]",                                        15, data)
	        rbit("marker_bit",                                          1)
	        rbit("DTS [14..0]",                                         15, data)
	        rbit("marker_bit",                                          1)

		    -- DTS値を計算
			--local DTS = data["DTS [32..30]"]*0x40000000 + data["DTS [29..15]"]*0x8000 + data["DTS [14..0]"]
		    --printf("# DTS=0x%09x (%10.3f sec)", DTS, DTS/90000)
	    end
   	    if data["ESCR_flag"] == 1 then
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
   	    if data["ES_rate_flag"] == 1 then
	        rbit("marker_bit",                                          1)
	        rbit("ES_rate",                                             22)
	        rbit("marker_bit",                                          1)
	    end
   	    if data["DSM_trick_mode_flag"] == 1 then
	        rbit("trick_mode_control",                                  3, data)
			if data["trick_mode_control"] == fast_forward then
				rbit("field_id",                                        2)
				rbit("intra_slice_refresh",                             1)
				rbit("frequency_truncation",                            2)
			elseif data["trick_mode_control"] == slow_motion then
				rbit("rep_cntrl",                                       5)
			elseif data["trick_mode_control"] == freeze_frame then
				rbit("field_id",                                        2)
				rbit("reserved",                                        3)
			elseif data["trick_mode_control"] == fast_reverse then 
				rbit("field_id",                                        2)
				rbit("intra_slice_refresh",                             1)
				rbit("frequency_truncation",                            2)
			elseif data["trick_mode_control"] == slow_reverse then
				rbit("rep_cntrl",                                       2)
			else
				rbit("reserved",                                        5)
			end
	    end
   	    if data["additional_copy_info_flag"] == 1 then
	        rbit("marker_bit",                                          1)
	        rbit("additional_copy_info",                                7)
	    end
   	    if data["PES_CRC_flag"] == 1 then
	        rbit("previous_PES_packet_CRC",                             16)
	    end
   	    if data["PES_extension_flag"] == 1 then
	        rbit("PES_private_data_flag",                               1)
	        rbit("pack_header_field_flag",                              1)
	        rbit("program_packet_sequence_counter_flag",                1)
	        rbit("P-STD_buffer_flag",                                   1)
	        rbit("reserved",                                            3)
	        rbit("PES_extension_flag_2",                                1)
   	  		if data["PES_private_data_flag"] == 1 then
	            rbit("PES_private_data",                                128)
	        end
   	  		if data["pack_header_field_flag"] == 1 then
	            rbit("pack_field_length",                               8, data)
	            rbit("pack_header()",                                   data["pack_field_length"])
	        end
   	  		if data["program_packet_sequence_counter_flag"] == 1 then
	            rbit("marker_bit",                                      1)
	            rbit("program_packet_sequence_counter",                 7)
	            rbit("marker_bit",                                      1)
	            rbit("MPEG1_MPEG2_identifier",                          1)
	            rbit("original_stuff_length",                           6)
	        end
   	  		if data["STD_buffer_flag"] == 1 then
	            rbit("'01'",                                            2)
	            rbit("P-STD_buffer_scale",                              1)
	            rbit("P-STD_buffer_size",                               13)
	        end
   	  		if data["PES_extension_flag_2"] == 1 then
	            rbit("marker_bit",                                      1)
	            rbit("PES_extension_field_length",                      7, data)
 	            rbyte("reserved",                                       data["PES_extension_field_length"])
	        end
	    end
	    
	    local N = data["PES_packet_length"] - (cur() - begin) + 6
	    --for i = 0; i < N1; i++) do
	    --    rbit("stuffing_byte",                                     N1) -- 0xFFデータ、デコーダがすてるはずでここではパースしない
	    --end
        if no_packet_length then
        	--vpes()
        else
	        wbyte("PES_packet_data_byte.dat",                           N)
        end
        
	elseif data["stream_id"] == program_stream_map
	or     data["stream_id"] == private_stream_2
	or     data["stream_id"] == ECM_stream
	or     data["stream_id"] == EMM_stream
	or     data["stream_id"] == program_stream_directory
	or     data["stream_id"] == ITU_T_Rec_H_222_0_ISO_IEC_13818_1_Annex_B_or_ISO_IEC_13818_6_DSMCC_stream
	or     data["stream_id"] == ITU_T_Rec_H_222_1_type_E then
	    wbyte("PES_packet_data_byte.es",                               data["PES_packet_length"])
	elseif ( stream_id == padding_stream) then
        rbyte("padding_byte",                                        data["PES_packet_length"])
	end

	-- return data["PES_packet_length"]
	return cur() - begin 
end

function pes_stream(size)
	local total_size = 0;
	while total_size < size do
		total_size = total_size + pes()
	end
end

-- ファイルオープン＆初期化＆解析
stream = open_stream(__stream_name__)
print_on(false)
pes_stream(file_size() - 1024*5) -- 解析開始、後半は5kb捨てる
print_status()


