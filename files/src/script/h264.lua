-- H264解析
function more_rbsp_data()
	return lbit(1) ~= 1
end

function rbsp_trailing_bits()
	local byte, bit = cur()
	cbit("rbsp_stop_one_bit",                          1,       1)
	cbit("rbsp_alignment_zero_bit",                    8-1-bit, 0) 
end

function byte_aligned()
	return select(2, cur()) == 0
end

function align_byte()
	if byte_aligned() == false then
		cbit("bit_equal_to_one",  1, 1)-- f(1)
	end
	while byte_aligned() == false do
		cbit("bit_equal_to_zero",  1, 0)-- f(1)
	end
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

function scaling_list()
	assert(false)
end

function seq_parameter_set_rbsp()
print("seq_parameter_set_rbsp")
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
					if i <= 6 then
						scaling_list(get("ScalingList4x4["..i.."]"), 16,
							get("UseDefaultScalingMatrix4x4Flag["..i.."]"))
					else
						scaling_list(get("ScalingList8x8["..(i-6).."]"), 64,
							get("UseDefaultScalingMatrix8x8Flag["..(i-6).."]"))
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
	end

	rbit("pic_struct_present_flag",                           1)

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

function pic_parameter_set_rbsp()
print("pic_parameter_set_rbsp")
	rexp("pic_parameter_set_id"                                   )  -- ue(v)
	rexp("seq_parameter_set_id"                                   )  -- ue(v)
	rbit("entropy_coding_mode_flag",                              1) -- u(1)
	rbit("bottom_field_pic_order_in_frame_present_flag",          1) -- u(1)
	rexp("num_slice_groups_minus1"                                )  -- ue(v)
	if get("num_slice_groups_minus1") > 0 then
		rexp("slice_group_map_type"                               )  -- ue(v)
		if get("slice_group_map_type") == 0 then
			for iGroup = 1, num_slice_groups_minus1 do
				rexp("run_length_minus1["..iGroup.."]"            )  -- ue(v)
			end
		elseif get("slice_group_map_type") == 2 then
			for iGroup = 1, num_slice_groups_minus1 do
				rexp("top_left["..iGroup.."]"                     )  -- ue(v)
				rexp("bottom_right["..iGroup.."]"                 )  -- ue(v)
			end
		elseif get("slice_group_map_type") == 3
		or     get("slice_group_map_type") == 4
		or     get("slice_group_map_type") == 5 then
			rbit("slice_group_change_direction_flag",             1) -- u(1)
			rexp("slice_group_change_rate_minus1"                 )  -- ue(v)
		elseif get("slice_group_map_type") == 6 then
			rexp("pic_size_in_map_units_minus1"                   )  -- ue(v)
			for i = 1, pic_size_in_map_units_minus1 do
				rbit("slice_group_id["..i.."]",                   1) -- u(v)
			end
		end
	end
	rexp("num_ref_idx_l0_default_active_minus1"                   )  -- ue(v)
	rexp("num_ref_idx_l1_default_active_minus1"                   )  -- ue(v)
	rbit("weighted_pred_flag",                                    1) -- u(1)
	rbit("weighted_bipred_idc",                                   2) -- u(2)
	rexp("pic_init_qp_minus26"                                    )  -- se(v)
	rexp("pic_init_qs_minus26"                                    )  -- se(v)
	rexp("chroma_qp_index_offset"                                 )  -- se(v)
	rbit("deblocking_filter_control_present_flag",                1) -- u(1)
	rbit("constrained_intra_pred_flag",                           1) -- u(1)
	rbit("redundant_pic_cnt_present_flag",                        1) -- u(1)
	if more_rbsp_data() then
		rbit("transform_8x8_mode_flag",                           1) -- u(1)
		rbit("pic_scaling_matrix_present_flag",                   1) -- u(1)
		if pic_scaling_matrix_present_flag then
			for i = 1, 6 + (get("chroma_format_idc") ~= 3 and 2 or 6) * get("transform_8x8_mode_flag") do
				rbit("pic_scaling_list_present_flag["..i.."]",    1) -- u(1)
				if get("pic_scaling_list_present_flag["..i.."]") then
					if i <= 6 then
						scaling_list(
							get("ScalingList4x4["..i.."]"),
							16,
							get("UseDefaultScalingMatrix4x4Flag["..i.."]"))
					else
						scaling_list(
							get("ScalingList8x8["..(i-6).."]"),
							64,
							get("UseDefaultScalingMatrix8x8Flag["..(i-6).."]"))
					end
				end
			end
		end
		rexp("second_chroma_qp_index_offset",                    1) -- se(v)
	end
	rbsp_trailing_bits()
end

function sei_rbsp()
	repeat
		sei_message()
	until more_rbsp_data() == false
	rbsp_trailing_bits()
end

function sei_message()
	local payloadType = 0
	while lbyte(1) == 0xff do
		cbit("ff_byte",                  5) -- f(8)
		payloadType = payloadType + 255
	end
	rbit("last_payload_type_byte",       5) -- u(8)
	payloadType = payloadType + get("last_payload_type_byte")

	payloadSize = 0
	while lbyte(1) == 0xff do
		cbit("ff_byte",                  5) -- f(8)
		payloadSize = payloadSize + 255
	end
	rbit("last_payload_size_byte",       5) -- u(8)
	payloadSize = payloadSize + get("last_payload_size_byte")

	sei_payload(payloadType, payloadSize)
end

function sei_payload(payloadType, payloadSize)
print("sei tyep, size = ", payloadType, payloadSize)
dump()
	local begin = cur()

	if payloadType == 0 then
		buffering_period(payloadSize)
	elseif payloadType == 1 then
		print("pic_timing( payloadSize ) 5")
	elseif payloadType == 2 then
		print("pan_scan_rect( payloadSize ) 5")
	elseif payloadType == 3 then
		print("filler_payload( payloadSize ) 5")
	elseif payloadType == 4 then
		print("user_data_registered_itu_t_t35( payloadSize ) 5")
	elseif payloadType == 5 then
		print("user_data_unregistered( payloadSize ) 5")
	elseif payloadType == 6 then
		print("recovery_point( payloadSize ) 5")
	elseif payloadType == 7 then
		print("dec_ref_pic_marking_repetition( payloadSize ) 5")
	elseif payloadType == 8 then
		print("spare_pic( payloadSize ) 5")
	elseif payloadType == 9 then
		print("scene_info( payloadSize ) 5")
	elseif payloadType == 10 then
		print("sub_seq_info( payloadSize ) 5")
	elseif payloadType == 11 then
		print("sub_seq_layer_characteristics( payloadSize ) 5")
	elseif payloadType == 12 then
		print("sub_seq_characteristics( payloadSize ) 5")
	elseif payloadType == 13 then
		print("full_frame_freeze( payloadSize ) 5")
	elseif payloadType == 14 then
		print("full_frame_freeze_release( payloadSize ) 5")
	elseif payloadType == 15 then
		print("full_frame_snapshot( payloadSize ) 5")
	elseif payloadType == 16 then
		print("progressive_refinement_segment_start( payloadSize ) 5")
	elseif payloadType == 17 then
		print("progressive_refinement_segment_end( payloadSize ) 5")
	elseif payloadType == 18 then
		print("motion_constrained_slice_group_set( payloadSize ) 5")
	elseif payloadType == 19 then
		print("film_grain_characteristics( payloadSize ) 5")
	elseif payloadType == 20 then
		print("deblocking_filter_display_preference( payloadSize ) 5")
	elseif payloadType == 21 then
		print("stereo_video_info( payloadSize ) 5")
	elseif payloadType == 22 then
		print("post_filter_hint( payloadSize ) 5")
	elseif payloadType == 23 then
		print("tone_mapping_info( payloadSize ) 5")
	elseif payloadType == 24 then
		print("scalability_info( payloadSize )  5")
	elseif payloadType == 25 then
		print("sub_pic_scalable_layer( payloadSize )  5")
	elseif payloadType == 26 then
		print("non_required_layer_rep( payloadSize )  5")
	elseif payloadType == 27 then
		print("priority_layer_info( payloadSize )  5")
	elseif payloadType == 28 then
		print("layers_not_present( payloadSize )  5")
	elseif payloadType == 29 then
		print("layer_dependency_change( payloadSize )  5")
	elseif payloadType == 30 then
		print("scalable_nesting( payloadSize )  5")
	elseif payloadType == 31 then
		print("base_layer_temporal_hrd( payloadSize )  5")
	elseif payloadType == 32 then
		print("quality_layer_integrity_check( payloadSize )  5")
	elseif payloadType == 33 then
		print("redundant_pic_property( payloadSize )  5")
	elseif payloadType == 34 then
		print("tl0_dep_rep_index( payloadSize )  5")
	elseif payloadType == 35 then
		print("tl_switching_point( payloadSize )  5")
	elseif payloadType == 36 then
		print("parallel_decoding_info( payloadSize )  5")
	elseif payloadType == 37 then
		print("mvc_scalable_nesting( payloadSize )  5")
	elseif payloadType == 38 then
		print("view_scalability_info( payloadSize )  5")
	elseif payloadType == 39 then
		print("multiview_scene_info( payloadSize )  5")
	elseif payloadType == 40 then
		print("multiview_acquisition_info( payloadSize )  5")
	elseif payloadType == 41 then
		print("non_required_view_component( payloadSize )  5")
	elseif payloadType == 42 then
		print("view_dependency_change( payloadSize )  5")
	elseif payloadType == 43 then
		print("operation_points_not_present( payloadSize )  5")
	elseif payloadType == 44 then
		print("base_view_temporal_hrd( payloadSize )  5")
	elseif payloadType == 45 then
		print("frame_packing_arrangement( payloadSize ) 5")
	elseif payloadType == 46 then
		print("multiview_view_position( payloadSize )  5")
	elseif payloadType == 47 then
		print("display_orientation( payloadSize ) 5")
	elseif payloadType == 48 then
		print("mvcd_scalable_nesting( payloadSize )  5")
	elseif payloadType == 49 then
		print("mvcd_view_scalability_info( payloadSize )  5")
	elseif payloadType == 50 then
		print("depth_representation_info( payloadSize )  5")
	elseif payloadType == 51 then
		print("three_dimensional_reference_displays_info( payloadSize ) 5")
	elseif payloadType == 52 then
		print("depth_timing( payloadSize )  5")
	elseif payloadType == 53 then
		print("depth_sampling_info( payloadSize )  5")
	else
		print("reserved_sei_message( payloadSize )")
	end
	
	if cur()-begin ~= payloadSize then
		rbyte("remained payload",  payloadSize - (cur() - begin))
	end

	rbsp_trailing_bits()
end

function buffering_period(payloadSize)
	rexp("seq_parameter_set_id")-- ue(v)
--	if get("NalHrdBpPresentFlag") then
--	Rec. ITU-T H.264 (04/2013) 329
--	for( SchedSelIdx = 0; SchedSelIdx <= cpb_cnt_minus1; SchedSelIdx++ ) {
--	initial_cpb_removal_delay[ SchedSelIdx ] 5 u(v)
--	initial_cpb_removal_delay_offset[ SchedSelIdx ] 5 u(v)
--	}
--	if( VclHrdBpPresentFlag )
--	for( SchedSelIdx = 0; SchedSelIdx <= cpb_cnt_minus1; SchedSelIdx++ ) {
--	initial_cpb_removal_delay[ SchedSelIdx ] 5 u(v)
--	initial_cpb_removal_delay_offset[ SchedSelIdx ] 5 u(v)
--	end
end

function nal_unit(NumBytesInNALunit)
print("nal_unit")
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

-- バイト数の計算が面倒くさそうなのでとりあえずすぐにreturnする
--	local total = nalUnitHeaderBytes
--	while total < NumBytesInNALunit do

		-- 本来03の除去はここで行うべき
		-- このスクリプトでは事前に000003を抜いているのでおかしくなるストリームもあるかも
		--if i + 2 < NumBytesInNALunit
		-- and lbyte(3) == 0x000003 then 
		-- 	tbyte("rbsp_byte",                              2)
		-- 	rbit("emulation_prevention_three_byte",         8)
		-- 	NumBytesInRBSP = NumBytesInRBSP + 2
		-- 	i = i + 2
		-- else
		--	tbyte("rbsp_byte",                              1)
		--end
		local begin = cur()
	
		if get("nal_unit_type") == 0 then
			print("Unspecified RBSP")
		elseif get("nal_unit_type") == 6 then
			sei_rbsp()
		elseif get("nal_unit_type") == 7 then
			seq_parameter_set_rbsp()
		elseif get("nal_unit_type") == 8 then
			pic_parameter_set_rbsp()
		elseif get("nal_unit_type") == 9 then
			access_unit_delimiter_rbsp()
			
			
			
			
		else
			seekoff(1, 0)
			print("seek")
			--rbyte("rbsp_byte",                              1)
		end
		
--		total = total + cur() - begin
--	end
end

function byte_stream_nal_unit(NumBytesInNALunit)
	local begin = cur()
	
	while lbyte(3) ~= 0x000001
	and lbyte(4) ~= 0x00000001 do
		cbyte("leading_zero_8bits",                     1, 0)
	end
	
	if lbyte(3) ~= 0x000001 then
		cbyte("zero_byte",                              1, 0)
	end
	cbyte("start_code_prefix_one_3bytes",               3, 0x000001)
	nal_unit(NumBytesInNALunit)
	
	while NumBytesInNALunit > begin - cur()
	and lbyte(3) ~= 0x000001
	and lbyte(4) ~= 0x00000001 do
		cbit("trailing_zero_8bits",                     8, 0)
	end
	
	return cur() - begin
end

function h264_byte_stream(max_length)
	local total_size = 0;
	while total_size < max_length do
		total_size = total_size + byte_stream_nal_unit(max_length-total_size)
		-- if lbyte(3) == 0x000001 then
		-- 	break
		-- end
	end
end

function remove_dummy(max_length, path)
	print("replace 00 00 03 -> 00 00")
	local ofs = 0
	while true do
		if cur() >= max_length then
			break
		end

		ofs = fstr("00 00 03", false)
		if cur() + ofs >= max_length then 
			tbyte(path, ofs)
			break
		end

		tbyte(path, ofs+2)
		rbyte("dummy", 1)
	end
end

-- 解析
if __stream_path__ ~= __stream_dir__.."removed03.h264" then
	open(__stream_path__)
	print_status()
	enable_print(true)
	stdout_to_file(false)
	start_thread(remove_dummy, file_size(), __stream_dir__.."removed03.h264")
end

open(__stream_dir__.."removed03.h264")
print_status()
enable_print(true)
stdout_to_file(false)
start_thread(h264_byte_stream, file_size())


