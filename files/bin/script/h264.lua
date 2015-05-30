-- H264âêÕ

function rbsp_trailing_bits()
	local byte, bit = cur()
	cbit("rbsp_stop_one_bit",                          1,       1)
	cbit("rbsp_alignment_zero_bit",                    8-1-bit, 0) 
end

function nal_unit_header_svc_extension()
	assert("false")
end

function nal_unit_header_mvc_extension()
	assert("false")
end

function get_slice_type_str(t)
	if     t == 0 then return "P "
	elseif t == 1 then return "B "
	elseif t == 2 then return "I "
	elseif t == 3 then return "SP "
	elseif t == 4 then return "SI "
	elseif t == 5 then return "P "
	elseif t == 6 then return "B "
	elseif t == 7 then return "I "
	elseif t == 8 then return "SP "
	elseif t == 9 then return "SI "
	else               return "? "     
	end
end

function access_unit_delimiter_rbsp()
	rbit("primary_pic_type",                            3)
	
	local t = get("primary_pic_type")
	local st = get_slice_type_str

	if     t == 0 then print("AUD", st(2), st(7)) 
	elseif t == 1 then print("AUD", st(1), st(0), st(2), st(5), st(7)) 
	elseif t == 2 then print("AUD", st(2), st(0), st(1), st(2), st(5), st(6), st(7))
	elseif t == 3 then print("AUD", st(3), st(4), st(9))
	elseif t == 4 then print("AUD", st(4), st(3), st(4), st(8), st(9))
	elseif t == 5 then print("AUD", st(5), st(2), st(4), st(7), st(9))
	elseif t == 6 then print("AUD", st(6), st(0), st(2), st(3), st(4), st(5), st(7), st(8), st(9))
	elseif t == 7 then print("AUD", st(7), st(0), st(1), st(2), st(3), st(4), st(5), st(6), st(7), st(8), st(9))
	else               print("AUD", "unknown")
	end
	
	rbsp_trailing_bits()
end

function seq_parameter_set_rbsp()
	rbit("profile_idc",                                    8)
	rbit("constraint_set0_flag",                           1)
	rbit("constraint_set1_flag",                           1)
	rbit("constraint_set2_flag",                           1)
	rbit("constraint_set3_flag",                           1)
	rbit("constraint_set4_flag",                           1)
	rbit("constraint_set5_flag",                           1)
	rbit("reserved_zero_2bits",                            2, 0)
	rbit("level_idc",                                      8)
	rexp("seq_parameter_set_id"                            )

	local p = get("profile_idc")
	if p == 100 or p == 110 
	or p == 122 or p == 244 or p == 44
	or p == 83  or p == 86  or p == 118 
	or p == 128 or p == 138 then
		rexp("chroma_format_idc"                           )
		if get("chroma_format_idc") == 3 then
			rbit("separate_colour_plane_flag",             1)
		end
		rexp("bit_depth_luma_minus8"                       )
		rexp("bit_depth_chroma_minus8"                     )
		rbit("qpprime_y_zero_transform_bypass_flag",       1)
		rbit("seq_scaling_matrix_present_flag",            1)
		
		if get("seq_scaling_matrix_present_flag") then
			local num
			if get("chroma_format_idc") ~= 3 then
				num = 8
			else
				num = 12
			end
			for i = 0, num do
				rbit("seq_scaling_list_present_flag",          1)
				if get("seq_scaling_list_present_flag") then
					if i < 6 then
						scaling_list(ScalingList4x4[i], 16, UseDefaultScalingMatrix4x4Flag[i])
					else
						scaling_list(ScalingList8x8[i-6], 64, UseDefaultScalingMatrix8x8Flag[i-6])
					end
				end
			end	
		end
	end

	rexp("log2_max_frame_num_minus4"                   )
	rexp("pic_order_cnt_type"                          )
	if get("pic_order_cnt_type") == 0 then
		rexp("log2_max_pic_order_cnt_lsb_minus4"       )
	elseif get("pic_order_cnt_type") == 1 then
		rbit("delta_pic_order_always_zero_flag",       1)
		rexp("offset_for_non_ref_pic"                  )
		rexp("offset_for_top_to_bottom_field"          )
		rexp("num_ref_frames_in_pic_order_cnt_cycle"   )
		for  i = 0, get("num_ref_frames_in_pic_order_cnt_cycle") do
			rexp("offset_for_ref_frame[i]"             )
		end
	end
	rexp("max_num_ref_frames"                          )
	rbit("gaps_in_frame_num_value_allowed_flag",       1)
	rexp("pic_width_in_mbs_minus1"                     )
	rexp("pic_height_in_map_units_minus1"              )

	print("width :", (get("pic_width_in_mbs_minus1")+1)*16)
	print("height:", (get("pic_height_in_map_units_minus1")+1)*16)

	rbit("frame_mbs_only_flag",                        1)
	if get("frame_mbs_only_flag") == 0 then
		rbit("mb_adaptive_frame_field_flag",           1)
	end
	rbit("direct_8x8_inference_flag",                  1)
	rbit("frame_cropping_flag",                        1)
	if get("frame_cropping_flag") == 1 then
		rexp("frame_crop_left_offset"                  )
		rexp("frame_crop_right_offset"                 )
		rexp("frame_crop_top_offset"                   )
		rexp("frame_crop_bottom_offset"                )
	end
	rbit("vui_parameters_present_flag",                1)
	if get("vui_parameters_present_flag") then
		vui_parameters()
	end
	rbsp_trailing_bits()
end

function vui_parameters()
print("vui_parameters")
	rbit("aspect_ratio_info_present_flag",                    1)
	if get("aspect_ratio_info_present_flag") == 1 then     
		rbit("aspect_ratio_idc",                              8)
		if get("aspect_ratio_idc") == 255 then  
			rbit("sar_width",                                 16)
			rbit("sar_height",                                16)
		end
	end

	rbit("overscan_info_present_flag",                        1)
	if get("overscan_info_present_flag") == 1 then 
		rbit("overscan_appropriate_flag",                     1)
	end

	rbit("video_signal_type_present_flag",                    1)
	if get("video_signal_type_present_flag") == 1 then     
		rbit("video_format",                                  3)
		rbit("video_full_range_flag",                         1)
		rbit("colour_description_present_flag",               1)
		if get("colour_description_present_flag") == 1 then  
			rbit("colour_primaries",                          8)
			rbit("transfer_characteristics",                  8)
			rbit("matrix_coefficients",                       8)
		end
	end

	rbit("chroma_loc_info_present_flag",                      1)
	if get("chroma_loc_info_present_flag") == 1 then  
		rexp("chroma_sample_loc_type_top_field"               )
		rexp("chroma_sample_loc_type_bottom_field"            )
	end

dump()
	rbit("timing_info_present_flag",                          1)
	if get("timing_info_present_flag") == 1 then  
		rbit("num_units_in_tick",                             32)
		rbit("time_scale",                                    32)
		rbit("fixed_frame_rate_flag",                         1)
	end

	rbit("nal_hrd_parameters_present_flag",                   1)
	if get("nal_hrd_parameters_present_flag") == 1 then 
		hrd_parameters()
	end

	rbit("vcl_hrd_parameters_present_flag",                   1)
	if get("vcl_hrd_parameters_present_flag") == 1 then 
		rbit("hrd_parameters",                                0)
	end
	
	if get("nal_hrd_parameters_present_flag") == 1
	or get("vcl_hrd_parameters_present_flag") == 1 then 
		rbit("low_delay_hrd_flag",                            1)
		rbit("pic_struct_present_flag",                       1)
	end

	rbit("bitstream_restriction_flag",                        1)
	if get("bitstream_restriction_flag") == 1 then  
		rbit("motion_vectors_over_pic_boundaries_flag",       1)
		rexp("max_bytes_per_pic_denom"                         )
		rexp("max_bits_per_mb_denom"                           )
		rexp("log2_max_mv_length_horizontal"                   )
		rexp("log2_max_mv_length_vertical"                     )
		rexp("max_num_reorder_frames"                          )
		rexp("max_dec_frame_buffering"                         )
	end
end

function nal_unit(NumBytesInNALunit)
	rbit("forbidden_zero_bit",                          1)
	rbit("nal_ref_idc",                                 2)
    rbit("nal_unit_type",                               5)
	
	local NumBytesInRBSP = 0
	local nalUnitHeaderBytes = 1
	if get("nal_unit_type") == 14
	or get("nal_unit_type") == 20
	or get("nal_unit_type") == 21 then
		rbit("svc_extension_flag",                      1)
		if get("svc_extension_flag") then
			nal_unit_header_svc_extension()
		else
			nal_unit_header_mvc_extension()
		end
		nalUnitHeaderBytes = nalUnitHeaderBytes + 3
	end

	for i=1, nalUnitHeaderBytes do
		if get("nal_unit_type") == 7 then
			seq_parameter_set_rbsp()
		elseif get("nal_unit_type") == 8 then
			pic_parameter_set_rbsp( )
		elseif get("nal_unit_type") == 9 then
			access_unit_delimiter_rbsp()
		else
			if i + 2 < NumBytesInNALunit
			and gbyte(3) == 0x000003 then 
				wbyte("rbsp_byte",                              2)
				rbit("emulation_prevention_three_byte",         8)
				NumBytesInRBSP = NumBytesInRBSP + 2
				i = i + 2
			else
				wbyte("rbsp_byte",                              1)
			end
		end
	end
end

function byte_stream_nal_unit(NumBytesInNALunit)
	local begin = cur()
	
	while gbyte(3) ~= 0x000001
	and gbyte(4) ~= 0x00000001 do
		cbyte("leading_zero_8bits",                     1, 0)
	end
	
	if gbyte(3) ~= 0x000001 then
		cbyte("zero_byte",                              1, 0)
	end
	cbyte("start_code_prefix_one_3bytes",               3, 0x000001)
	nal_unit(NumBytesInNALunit)
	
	while NumBytesInNALunit > begin - cur()
	and gbyte(3) ~= 0x000001
	and gbyte(4) ~= 0x00000001 do
		cbit("trailing_zero_8bits",                     8, 0)
	end
	
	return cur() - begin
end

function h264_byte_stream(max_length)
	local total_size = 0;
	while total_size < max_length do
		total_size = total_size + byte_stream_nal_unit(max_length-total_size)
		if gbyte(3) == 0x000001 then
			break
		end
	end
end

function remove_dummy(max_length)
	print("replace 00 00 03 -> 00 00")
	local ofs = 0
	local path = __stream_dir__.."removed03.h264"
	while true do
		if cur() >= max_length then
			break
		end

		ofs = fstr("00 00 03", false)
		if cur() + ofs >= max_length then 
			wbyte(path, ofs)
			break
		end

		wbyte(path, ofs+2)
		rbyte("dummy", 1)
	end
	
	return path
end

-- âêÕ
open(__stream_path__)
print_status()
enable_print(true)
stdout_to_file(false)
local removed_path = analyse(remove_dummy, file_size())

print(removed_path)

open(removed_path)
print_status()
enable_print(true)
stdout_to_file(false)
analyse(h264_byte_stream, file_size())


