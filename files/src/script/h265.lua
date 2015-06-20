-- H264解析

local TRAIL_N        = 0 
local TRAIL_R        = 1 
local TSA_N          = 2 
local TSA_R          = 3 
local STSA_N         = 4 
local STSA_R         = 5 
local RADL_N         = 6 
local RADL_R         = 7 
local RASL_N         = 8 
local RASL_R         = 9 
local RSV_VCL_N      = 10
local RSV_VCL_N      = 12
local RSV_VCL_N      = 14
local RSV_VCL_R      = 11
local RSV_VCL_R      = 13
local RSV_VCL_R      = 15
local BLA_W_LP       = 16
local BLA_W_RADL     = 17
local BLA_N_LP       = 18
local IDR_W_RADL     = 19
local IDR_N_LP       = 20
local CRA_NUT        = 21
local RSV_IRAP_VCL22 = 22
local RSV_IRAP_VCL23 = 23
local B = 0 -- (B slice)
local P = 1 -- (P slice)
local I = 2 -- (I slice)

function reset_initial_values()
end

function more_rbsp_data()
	if cur() >= get_size() then
		return false
	end
	return lbit(1) ~= 1
end

function more_data_in_byte_stream()
	return cur() < get_size()
end

function byte_aligned()
	return select(2, cur()) == 0
end


function nal_unit_header_svc_extension()
	assert("false")
	rbyte("nal_unit_header_svc_extension", 2)
end

function nal_unit_header_mvc_extension()
	assert("false")
	rbyte("nal_unit_header_mvc_extension", 2)
end

function video_parameter_set_rbsp()
print("video_parameter_set_rbsp")
	rbit("vps_video_parameter_set_id",                                  4)  -- u(4)
	rbit("vps_base_layer_internal_flag",                                1)  -- u(1)
	rbit("vps_base_layer_available_flag",                               1)  -- u(1)
	rbit("vps_max_layers_minus1",                                       6)  -- u(6)
	rbit("vps_max_sub_layers_minus1",                                   3)  -- u(3)
	rbit("vps_temporal_id_nesting_flag",                                1)  -- u(1)
	rbit("vps_reserved_0xffff_16bits",                                  16) -- u(16)
	profile_tier_level(1, get("vps_max_sub_layers_minus1"))
	rbit("vps_sub_layer_ordering_info_present_flag",                    1)  -- u(1)

	local i = get("vps_sub_layer_ordering_info_present_flag") and 0 or get("vps_max_sub_layers_minus1")
	for i = i, get("vps_max_sub_layers_minus1") do
		rexp("vps_max_dec_pic_buffering_minus1[i]"                    )   -- ue(v)
		rexp("vps_max_num_reorder_pics[i]"                            )   -- ue(v)
		rexp("vps_max_latency_increase_plus1[i]"                      )   -- ue(v)
	end
	rbit("vps_max_layer_id",                                            6)  -- u(6)
	rexp("vps_num_layer_sets_minus1"                                    )   -- ue(v)
	for i = 0, get("vps_num_layer_sets_minus1") - 1 do
		for j = 0, get("vps_max_layer_id") do
			rbit("layer_id_included_flag[i][j]",                    1)  -- u(1)
		end
	end
	rbit("vps_timing_info_present_flag",                        1)  -- u(1)
	if get("vps_timing_info_present_flag") == 1 then
		rbit("vps_num_units_in_tick",                           32) -- u(32)
		rbit("vps_time_scale",                                  32) -- u(32)
		rbit("vps_poc_proportional_to_timing_flag",             1)  -- u(1)
		if get("vps_poc_proportional_to_timing_flag") == 1 then
			rexp("vps_num_ticks_poc_diff_one_minus1"            )   -- ue(v)
		end
		rexp("vps_num_hrd_parameters"                           )   -- ue(v)
		for i = 0, get("vps_num_hrd_parameters") - 1 do
			rexp("hrd_layer_set_idx[i]"                       )   -- ue(v)
			if i > 1 then
				rbit("cprms_present_flag[i]",                 1)  -- u(1)
			end
			hrd_parameters( get("cprms_present_flag[i]"), get("vps_max_sub_layers_minus1") )
		end
	end
	rbit("vps_extension_flag",                                          1)  -- u(1)
	if get("vps_extension_flag") == 1 then
		while byte_aligned() ~= true do
			rbit("vps_extension_alignment_bit_equal_to_one",            1)  -- u(1)
		end
		vps_extension()
		rbit("vps_extension2_flag",                                     1)  -- u(1)
		if get("vps_extension2_flag") then
			while more_rbsp_data() do
				rbit("vps_extension_data_flag",                         1)  -- u(1)
			end
		end
	end
	rbsp_trailing_bits()
end


function seq_parameter_set_rbsp()
print("seq_parameter_set_rbsp")
	rbit("sps_video_parameter_set_id",                     4)
	rbit("sps_max_sub_layers_minus1",                      3)
	rbit("sps_temporal_id_nesting_flag",                   1)
	profile_tier_level(1, get("sps_max_sub_layers_minus1"))
	rexp("sps_seq_parameter_set_id"                        )
	rexp("chroma_format_idc"                               )
	if get("chroma_format_idc") == 3 then
		rbit("separate_colour_plane_flag",                 1)
	end
	
	rexp("pic_width_in_luma_samples"                       )
	rexp("pic_height_in_luma_samples"                      )
	rbit("conformance_window_flag",                        1)
	
	print("width  = "..hexstr(get("pic_width_in_luma_samples")))
	print("height = "..hexstr(get("pic_height_in_luma_samples")))

	if get("conformance_window_flag") == 1 then
		rexp("conf_win_left_offset")      
		rexp("conf_win_right_offset")     
		rexp("conf_win_top_offset")       
		rexp("conf_win_bottom_offset")    
	end

	rexp("bit_depth_luma_minus8"                       )
	rexp("bit_depth_chroma_minus8"                     )
	rexp("log2_max_pic_order_cnt_lsb_minus4"           )
	rbit("sps_sub_layer_ordering_info_present_flag",   1)
	
	local ini = get("sps_sub_layer_ordering_info_present_flag") and 0 or get("sps_max_sub_layers_minus1")
	for i = ini, get("sps_max_sub_layers_minus1") do
		rexp("sps_max_dec_pic_buffering_minus1[i]"     )
		rexp("sps_max_num_reorder_pics[i]"             )
		rexp("sps_max_latency_increase_plus1[i]"       )
	end

	rexp("log2_min_luma_coding_block_size_minus3"      )
	rexp("log2_diff_max_min_luma_coding_block_size"    )
	rexp("log2_min_luma_transform_block_size_minus2"   )
	rexp("log2_diff_max_min_luma_transform_block_size" )
	rexp("max_transform_hierarchy_depth_inter"         )
	rexp("max_transform_hierarchy_depth_intra"         )
	rbit("scaling_list_enabled_flag",                  1)
	
	if get("scaling_list_enabled_flag") == 1 then
		rbit("sps_scaling_list_data_present_flag",     1)
		if get("sps_scaling_list_data_present_flag") == 1 then
			scaling_list_data( )
		end
	end
	
	rbit("amp_enabled_flag",                                 1)
	rbit("sample_adaptive_offset_enabled_flag",              1)
	rbit("pcm_enabled_flag",                                 1)
	if get("pcm_enabled_flag") == 1 then
		rbit("pcm_sample_bit_depth_luma_minus1",             1)
		rbit("pcm_sample_bit_depth_chroma_minus1",           1)
		rexp("log2_min_pcm_luma_coding_block_size_minus3"    )
		rexp("log2_diff_max_min_pcm_luma_coding_block_size"  )
		rbit("pcm_loop_filter_disabled_flag",                1)
	end
	
	rexp("num_short_term_ref_pic_sets"                       )

	for  i = 0, get("num_short_term_ref_pic_sets") - 1 do
		st_ref_pic_set( i )
	end
	rbit("long_term_ref_pics_present_flag",                    1) -- u(1))
	if get("long_term_ref_pics_present_flag") == 1 then 
		rexp("num_long_term_ref_pics_sps"                      ) -- ue(v))
		for  i = 0, get("num_long_term_ref_pics_sps") - 1 do
			rbit("lt_ref_pic_poc_lsb_sps[i]",                      get("log2_max_pic_order_cnt_lsb_minus4") + 4) -- u(v))
			rbit("used_by_curr_pic_lt_sps_flag[i]",                1) -- u(1))
		end
	end
	
	rbit("sps_temporal_mvp_enabled_flag",                          1) -- u(1))
	rbit("strong_intra_smoothing_enabled_flag",                    1) -- u(1))
	rbit("vui_parameters_present_flag",                            1) -- u(1))
	
	if get("vui_parameters_present_flag") == 1 then
		vui_parameters( )
	end
	
	rbit("sps_extension_present_flag",                             1) -- u(1))
	
	if get("sps_extension_present_flag") == 1 then 
		rbit("sps_range_extension_flag",                           1) -- u(1))
		rbit("sps_multilayer_extension_flag",                      1) -- u(1))
		rbit("sps_extension_6bits",                                6) -- u(6))
	end
	
	if get("sps_range_extension_flag") == 1 then
		sps_range_extension( )
	end
	
	if get("sps_multilayer_extension_flag") == 1 then
		sps_multilayer_extension( ) -- specified in Annex F 
	end
	
	if get("sps_extension_6bits") == 1 then
		while more_rbsp_data( ) do
			rbit("sps_extension_data_flag",                        1) -- u(1))
			rbsp_trailing_bits( )
		end   
	end
end

function sps_range_extension( )
	rbit("transform_skip_rotation_enabled_flag",                  1) -- u(1))
	rbit("transform_skip_context_enabled_flag",                   1) -- u(1))
	rbit("implicit_rdpcm_enabled_flag",                           1) -- u(1))
	rbit("explicit_rdpcm_enabled_flag",                           1) -- u(1))
	rbit("extended_precision_processing_flag",                    1) -- u(1))
	rbit("intra_smoothing_disabled_flag",                         1) -- u(1))
	rbit("high_precision_offsets_enabled_flag",                   1) -- u(1))
	rbit("persistent_rice_adaptation_enabled_flag",               1) -- u(1))
	rbit("cabac_bypass_alignment_enabled_flag",                   1) -- u(1))
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
                                        
function pic_parameter_set_rbsp( ) 
print("pic_parameter_set_rbsp")
	rexp("pps_pic_parameter_set_id"                         ) -- ue(v))
	rexp("pps_seq_parameter_set_id"                         ) -- ue(v))
	rbit("dependent_slice_segments_enabled_flag",           1) -- u(1))
	rbit("output_flag_present_flag",                        1) -- u(1))
	rbit("num_extra_slice_header_bits",                     3) -- u(3))
	rbit("sign_data_hiding_enabled_flag",                   1) -- u(1))
	rbit("cabac_init_present_flag",                         1) -- u(1))
	rexp("num_ref_idx_l0_default_active_minus1"             ) -- ue(v))
	rexp("num_ref_idx_l1_default_active_minus1"             ) -- ue(v))
	rexp("init_qp_minus26"                                  ) -- se(v))
	rbit("constrained_intra_pred_flag",                     1) -- u(1))
	rbit("transform_skip_enabled_flag",                     1) -- u(1))
	rbit("cu_qp_delta_enabled_flag",                        1) -- u(1))
	if get("cu_qp_delta_enabled_flag") == 1 then
		rexp("diff_cu_qp_delta_depth"                       ) -- ue(v))
	end
	
	rexp("pps_cb_qp_offset"                                 ) -- se(v))
	rexp("pps_cr_qp_offset"                                 ) -- se(v))
	rbit("pps_slice_chroma_qp_offsets_present_flag",        1) -- u(1))
	rbit("weighted_pred_flag",                              1) -- u(1))
	rbit("weighted_bipred_flag",                            1) -- u(1))
	rbit("transquant_bypass_enabled_flag",                  1) -- u(1))
	rbit("tiles_enabled_flag",                              1) -- u(1))
	rbit("entropy_coding_sync_enabled_flag",                1) -- u(1))
	if get("tiles_enabled_flag") == 1 then 
		rexp("num_tile_columns_minus1"                      ) -- ue(v))
		rexp("num_tile_rows_minus1"                         ) -- ue(v))
		rbit("uniform_spacing_flag",                        1) -- u(1))
		if  get("uniform_spacing_flag") ~= 1 then 
			for i = 0, num_tile_columns_minus1-1  do
				rexp("column_width_minus1[i]"               ) -- ue(v))
			end
			for i = 0, num_tile_rows_minus1-1  do
				rexp("row_height_minus1[i]"                 ) -- ue(v))
			end
		end
		rbit("loop_filter_across_tiles_enabled_flag",       1) -- u(1))
	end
	rbit("pps_loop_filter_across_slices_enabled_flag",      1) -- u(1))
	rbit("deblocking_filter_control_present_flag",          1) -- u(1))
	if get("deblocking_filter_control_present_flag") == 1 then 
		rbit("deblocking_filter_override_enabled_flag",     1) -- u(1))
		rbit("pps_deblocking_filter_disabled_flag",         1) -- u(1))
		if get("pps_deblocking_filter_disabled_flag") ~= 1 then 
			rexp("pps_beta_offset_div2"                     ) -- se(v))
			rexp("pps_tc_offset_div2"                       ) -- se(v))
		end
	end
	
	rbit("pps_scaling_list_data_present_flag",              1) -- u(1))
	if get("pps_scaling_list_data_present_flag") == 1 then
		scaling_list_data( )
	end

	rbit("lists_modification_present_flag",                     1) -- u(1))
	rexp("log2_parallel_merge_level_minus2"                     ) -- ue(v))
	rbit("slice_segment_header_extension_present_flag",         1) -- u(1))

	rbit("pps_extension_present_flag",                          1) -- u(1))
	if get("pps_extension_present_flag") == 1 then 
		rbit("pps_range_extension_flag",                        1) -- u(1))
		rbit("pps_multilayer_extension_flag",                   1) -- u(1))
		rbit("pps_extension_6bits",                             6) -- u(6))
	end
	
	if get("pps_range_extension_flag") == 1 then
		pps_range_extension( )
	end	
	if get("pps_multilayer_extension_flag") == 1 then
		pps_multilayer_extension( ) -- specified in Annex F 
	end
	if get("pps_extension_6bits") == 1 then
		while more_rbsp_data( ) do
			rbit("pps_extension_data_flag",                      1) -- u(1))
		end
	end
end

function pps_range_extension()
	rbsp_trailing_bits( )
	
	if get("transform_skip_enabled_flag") == 1 then
		rexp("log2_max_transform_skip_block_size_minus2"             ) -- ue(v))
	end

	rbit("cross_component_prediction_enabled_flag",              1) -- u(1))
	rbit("chroma_qp_offset_list_enabled_flag",                   1) -- u(1))

	if get("chroma_qp_offset_list_enabled_flag") == 1 then 
		rexp("diff_cu_chroma_qp_offset_depth"                    ) -- ue(v))
		rexp("chroma_qp_offset_list_len_minus1"                  ) -- ue(v))
		for  i = 0, chroma_qp_offset_list_len_minus1  do 
			rexp("cb_qp_offset_list[i]"                          ) -- se(v))
			rexp("cr_qp_offset_list[i]"                          ) -- se(v))
		end
	end
	rexp("log2_sao_offset_scale_luma"                            ) -- ue(v))
	rexp("log2_sao_offset_scale_chroma"                          ) -- ue(v))
end

function sei_rbsp()
print("SEI")
	repeat
		sei_message()
	until more_rbsp_data() == false
	rbsp_trailing_bits()
end

function access_unit_delimiter_rbsp()
	rbit("pic_type",                            3)

	if     get("pic_type") == 0 then print("AUD I")  
	elseif get("pic_type") == 1 then print("AUD IP") 
	elseif get("pic_type") == 2 then print("AUD IPB")
	else print("AUD unknown")
	end
	
	rbsp_trailing_bits()
end

function end_of_seq_rbsp( ) 
end

function end_of_bitstream_rbsp( ) 
end

function filler_data_rbsp( ) 
	while lbit(8) == 0xFF do
		cbit("ff_byte", 8, 0xff) -- equal to 0xFF
		rbsp_trailing_bits( )
	end
end

function slice_segment_layer_rbsp(nal_unit_type) 
	slice_segment_header(nal_unit_type)
	--slice_segment_data(nal_unit_type)
	--rbsp_slice_segment_trailing_bits()
end

function rbsp_slice_segment_trailing_bits( ) 
	rbsp_trailing_bits( )
	while more_rbsp_trailing_data( ) do
		cbit("cabac_zero_word", 16, 0) -- f(16) equal to 0x0000                                               
	end
end

function rbsp_trailing_bits()
	local bit = select(2, cur())
	cbit("rbsp_stop_one_bit",                          1,       1)
	cbit("rbsp_alignment_zero_bit",                    8-1-bit, 0) 
end

function byte_alignment()
	cbit("alignment_bit_equal_to_one", 1, 1)      -- f(1)
	while byte_aligned() == false do
		cbit("alignment_bit_equal_to_zero", 1, 0) -- f(1)
	end
end

function profile_tier_level(profilePresentFlag, maxNumSubLayersMinus1 )
	if profilePresentFlag == 1 then
		rbit("general_profile_space",                            2) -- u(2)
		rbit("general_tier_flag",                                1) -- u(1)
		rbit("general_profile_idc",                              5) -- u(5)
		
		local general_profile_compatibility_flag = {}
		for j = 0, 32 - 1 do
			rbit("general_profile_compatibility_flag[j]",      1) -- u(1)
			general_profile_compatibility_flag[j-1] = get("general_profile_compatibility_flag[j]")
		end
		rbit("general_progressive_source_flag",              1) -- u(1)
		rbit("general_interlaced_source_flag",               1) -- u(1)
		rbit("general_non_packed_constraint_flag",           1) -- u(1)
		rbit("general_frame_only_constraint_flag",           1) -- u(1)

		local general_profile_idc = get("general_profile_idc")
		if general_profile_idc == 4 or general_profile_compatibility_flag[4] == 1
		or general_profile_idc == 5 or general_profile_compatibility_flag[5] == 1
		or general_profile_idc == 6 or general_profile_compatibility_flag[6] == 1
		or general_profile_idc == 7 or general_profile_compatibility_flag[7] == 1 then
			rbit("general_max_12bit_constraint_flag",        1) -- u(1)
			rbit("general_max_10bit_constraint_flag",        1) -- u(1)
			rbit("general_max_8bit_constraint_flag",         1) -- u(1)
			rbit("general_max_422chroma_constraint_flag",    1) -- u(1)
			rbit("general_max_420chroma_constraint_flag",    1) -- u(1)
			rbit("general_max_monochrome_constraint_flag",   1) -- u(1)
			rbit("general_intra_constraint_flag",            1) -- u(1)
			rbit("general_one_picture_only_constraint_flag", 1) -- u(1)
			rbit("general_lower_bit_rate_constraint_flag",   1) -- u(1)
			rbit("general_reserved_zero_34bits",             34) -- u(34)
		else
			rbit("general_reserved_zero_43bits",                     43) -- u(43)
		end

		if (general_profile_idc >= 1 and general_profile_idc <= 5)
		or general_profile_compatibility_flag[1] == 1 
		or general_profile_compatibility_flag[2] == 1 
		or general_profile_compatibility_flag[3] == 1 
		or general_profile_compatibility_flag[4] == 1 
		or general_profile_compatibility_flag[5] == 1 then
		 	rbit("general_inbld_flag",                     1) -- u(1)
		else
			rbit("general_reserved_zero_bit",              1) -- u(1)
		end
	end
	rbit("general_level_idc",                              8) -- u(8)
	
	local sub_layer_profile_present_flag = {}
	local sub_layer_level_present_flag = {}
	for i = 0, maxNumSubLayersMinus1 - 1 do
		rbit("sub_layer_profile_present_flag[i]",          1) -- u(1)
		rbit("sub_layer_level_present_flag[i]",            1) -- u(1)
		sub_layer_profile_present_flag[i-1] = get("sub_layer_profile_present_flag[i]")
		sub_layer_level_present_flag[i-1] = get("sub_layer_level_present_flag[i]")
	end
	if maxNumSubLayersMinus1 > 0 then
		for i = maxNumSubLayersMinus1, 8 - 1 do
			rbit("reserved_zero_2bits[i]",                 2) -- u(2)
		end
	end

	local sub_layer_profile_idc = {}
	local sub_layer_profile_compatibility_flag = {}
	for i = 0, maxNumSubLayersMinus1-1 do
		if sub_layer_profile_present_flag[i] == 1 then
			rbit("sub_layer_profile_space[i]",                         2) -- u(2)
			rbit("sub_layer_tier_flag[i]",                             1) -- u(1)
			rbit("sub_layer_profile_idc[i]",                           5) -- u(5)
			sub_layer_profile_idc[i] = get("sub_layer_profile_idc[i]")

			sub_layer_profile_compatibility_flag[i] = {}
			for j = 0, 32-1 do
				rbit("sub_layer_profile_compatibility_flag[i][j]",     1) -- u(1)
				sub_layer_profile_compatibility_flag[i-1][j-1] = get("sub_layer_profile_compatibility_flag[i][j]")
			end
			rbit("sub_layer_progressive_source_flag[i]",               1) -- u(1)
			rbit("sub_layer_interlaced_source_flag[i]",                1) -- u(1)
			rbit("sub_layer_non_packed_constraint_flag[i]",            1) -- u(1)
			rbit("sub_layer_frame_only_constraint_flag[i]",            1) -- u(1)			

			if sub_layer_profile_idc[i] == 4 or sub_layer_profile_compatibility_flag[i][4] == 1 
			or sub_layer_profile_idc[i] == 5 or sub_layer_profile_compatibility_flag[i][5] == 1 
			or sub_layer_profile_idc[i] == 6 or sub_layer_profile_compatibility_flag[i][6] == 1 
			or sub_layer_profile_idc[i] == 7 or sub_layer_profile_compatibility_flag[i][7] == 1 then
				rbit("sub_layer_max_12bit_constraint_flag[i]",         1) -- u(1)
				rbit("sub_layer_max_10bit_constraint_flag[i]",         1) -- u(1)
				rbit("sub_layer_max_8bit_constraint_flag[i]",          1) -- u(1)
				rbit("sub_layer_max_422chroma_constraint_flag[i]",     1) -- u(1)
				rbit("sub_layer_max_420chroma_constraint_flag[i]",     1) -- u(1)
				rbit("sub_layer_max_monochrome_constraint_flag[i]",    1) -- u(1)
				rbit("sub_layer_intra_constraint_flag[i]",             1) -- u(1)
				rbit("sub_layer_one_picture_only_constraint_flag[i]",  1) -- u(1)
				rbit("sub_layer_lower_bit_rate_constraint_flag[i]",    1) -- u(1)
				rbit("sub_layer_reserved_zero_34bits[i]",              34) -- u(34)
			else                                           
					rbit("sub_layer_reserved_zero_43bits[i]",          43) -- u(43)
			end
			
			if (sub_layer_profile_idc[i] >= 1 and sub_layer_profile_idc[i] <= 5) 
			or sub_layer_profile_compatibility_flag[1]  == 1 
			or sub_layer_profile_compatibility_flag[2]  == 1 
			or sub_layer_profile_compatibility_flag[3]  == 1 
			or sub_layer_profile_compatibility_flag[4]  == 1 
			or sub_layer_profile_compatibility_flag[5]  == 1 then
				rbit("sub_layer_inbld_flag[i]",                        1) -- u(1)
			else
				rbit("sub_layer_reserved_zero_bit[i]",                 1) -- u(1)
			end
		end
		if get(sub_layer_level_present_flag[i]) == 1then                                    
			rbit("sub_layer_level_idc[i]",                                 8) -- u(8)
		end
	end
end

function scaling_list_data( ) 
	ScalingList = {}
	for sizeId = 0, 4-1 do
		ScalingList[sizeId] = {}
		for matrixId = 0, 6-1, (sizeId == 3 and 3 or 1) do 
			rbit("scaling_list_pred_mode_flag[sizeId][matrixId]",                          1) -- u(1))
			if get("scaling_list_pred_mode_flag[sizeId][matrixId]") ~= 1 then
				rexp("scaling_list_pred_matrix_id_delta[sizeId][matrixId]"                 ) -- ue(v))
			else                                               	
				local nextCoef = 8
				coefNum = math.min(64, (1 << ( 4 + (sizeId << 1))))
				if sizeId > 1 then 
					rexp("scaling_list_dc_coef_minus8[sizeId - 2][matrixId]"               ) -- se(v)
					nextCoef = get("scaling_list_dc_coef_minus8[sizeId - 2][matrixId]") + 8
				end
				
				ScalingList[sizeId][matrixId] = {}
				for  i = 0, coefNum - 1 do 
					rexp("scaling_list_delta_coef"                                         ) -- se(v))
					nextCoef = ( nextCoef + get("scaling_list_delta_coef") + 256 ) % 256
					ScalingList[sizeId][matrixId][i] = nextCoef
				end
			end
		end
	end
end

function sei_message()
	local payloadType = 0
	while lbyte(1) == 0xff do
		cbit("ff_byte",                  8, 0xff) -- f(8)
		payloadType = payloadType + 255
	end
	rbit("last_payload_type_byte",       8, 0xff) -- u(8)
	payloadType = payloadType + get("last_payload_type_byte")

	payloadSize = 0
	while lbyte(1) == 0xff do
		cbit("ff_byte",                  8, 0xff) -- f(8)
		payloadSize = payloadSize + 255
	end
	rbit("last_payload_size_byte",       8, 0xff) -- u(8)
	payloadSize = payloadSize + get("last_payload_size_byte")

	sei_payload(payloadType, payloadSize)
end


function slice_segment_header(nal_unit_type)
print("slice_segment_header", nal_unit_type)
	rbit("first_slice_segment_in_pic_flag",                       1) -- u(1))
	if nal_unit_type >= BLA_W_LP and nal_unit_type <= RSV_IRAP_VCL23 then
		rbit("no_output_of_prior_pics_flag",                      1) -- u(1))
	end
	rexp("slice_pic_parameter_set_id"                             ) -- ue(v))
	if get("first_slice_segment_in_pic_flag") ~= 1 then 
		if get("dependent_slice_segments_enabled_flag") == 1 then
			rbit("dependent_slice_segment_flag",                  1) -- u(1))
		end
		rbit("slice_segment_address",                             v) -- u(v))
	end
	if get("dependent_slice_segment_flag") ~= 1 then 
		for  i = 0, get("num_extra_slice_header_bits")-1 do
			rbit("slice_reserved_flag[i]",                             1) -- u(1))
		end
		
		rexp("slice_type"                                              ) -- ue(v))
		if     get("slice_type") == 0 then print("slice_type = B")  
		elseif get("slice_type") == 1 then print("slice_type = P") 
		elseif get("slice_type") == 2 then print("slice_type = I")
		else print("unknown slice type")
		end

		if get("output_flag_present_flag") == 1 then
			rbit("pic_output_flag",                                    1) -- u(1))
		end
		
		if get("separate_colour_plane_flag") == 1 then
			rbit("colour_plane_id",                                    2) -- u(2))
		end
		
		if  nal_unit_type ~= IDR_W_RADL 
		and nal_unit_type ~= IDR_N_LP then 
			rbit("slice_pic_order_cnt_lsb",                            get("log2_max_pic_order_cnt_lsb_minus4") + 4) -- u(v))
			rbit("short_term_ref_pic_set_sps_flag",                    1) -- u(1))
		
			if get("short_term_ref_pic_set_sps_flag") ~= 1 then
				st_ref_pic_set( get("num_short_term_ref_pic_sets") )
			elseif get("num_short_term_ref_pic_sets") > 1 then
				rbit("short_term_ref_pic_set_idx",                     math.ceil(math.log(get("num_short_term_ref_pic_sets"), 2))) -- u(v))
			end
		
			if get("long_term_ref_pics_present_flag") == 1 then 
				if get("num_long_term_ref_pics_sps") > 0  then
					rexp("num_long_term_sps"                               ) -- ue(v))
				end
		
				rexp("num_long_term_pics"                                  ) -- ue(v))
				for i = 0, get("num_long_term_sps") + get("num_long_term_pics") - 1 do 
					if i < get("num_long_term_sps") then 
						if get("num_long_term_ref_pics_sps") > 1 then
							rbit("lt_idx_sps[i]",                          v) -- u(v))
						end
					else 
						rbit("poc_lsb_lt[i]",                              v) -- u(v))
						rbit("used_by_curr_pic_lt_flag[i]",                1) -- u(1))
					end
					rbit("delta_poc_msb_present_flag[i]",                  1) -- u(1))
					if get("delta_poc_msb_present_flag[i]") == 1 then
						rexp("delta_poc_msb_cycle_lt[i]"                   ) -- ue(v))
					end
				end
			end
			if get("sps_temporal_mvp_enabled_flag") == 1 then
				rbit("slice_temporal_mvp_enabled_flag",                    1) -- u(1))
			end
		end
		
		if get("sample_adaptive_offset_enabled_flag") == 1 then 
			rbit("slice_sao_luma_flag",                                1) -- u(1))
			if ChromaArrayType ~= 0 then
				rbit("slice_sao_chroma_flag",                          1) -- u(1))
			end
		end
		
		if get("slice_type") == P or get("slice_type") == B then 
			rbit("num_ref_idx_active_override_flag",                   1) -- u(1))
			if get("num_ref_idx_active_override_flag") == 1 then 
				rexp("num_ref_idx_l0_active_minus1"                        ) -- ue(v))
				if get("slice_type") == B then
					rexp("num_ref_idx_l1_active_minus1"                    ) -- ue(v))
				end
			else
				reset("num_ref_idx_l1_active_minus1", get("num_ref_idx_l1_default_active_minus1"))
			end
			
			if get("lists_modification_present_flag") == 1 and NumPicTotalCurr > 1 then
				ref_pic_lists_modification( )
			end

			if get("slice_type") == B then
				rbit("mvd_l1_zero_flag",                                   1) -- u(1))
			end

			if get("cabac_init_present_flag") == 1 then
				rbit("cabac_init_flag",                                    1) -- u(1))
			end

			if get("slice_temporal_mvp_enabled_flag") == 1 then 
				if get("slice_type") == B then
					rbit("collocated_from_l0_flag",                        1) -- u(1))
				else
					reset("collocated_from_l0_flag", 1)
				end
				if (get("collocated_from_l0_flag") == 1 and get("num_ref_idx_l0_active_minus1") > 0 )
				or (get("collocated_from_l0_flag") ~= 1 and get("num_ref_idx_l1_active_minus1") > 0 ) then
					rexp("collocated_ref_idx"                              ) -- ue(v))
				end
			end

			if ( get("weighted_pred_flag") == 1 and slice_type == P )
			or ( get("weighted_bipred_flag") == 1 and slice_type == B ) then
				pred_weight_table( )
			end
			rexp("five_minus_max_num_merge_cand"                           ) -- ue(v))
		end

		rexp("slice_qp_delta"                                              ) -- se(v))

		if get("pps_slice_chroma_qp_offsets_present_flag") == 1 then 
			rexp("slice_cb_qp_offset"                                      ) -- se(v))
			rexp("slice_cr_qp_offset"                                      ) -- se(v))
		end

		if get("chroma_qp_offset_list_enabled_flag") == 1 then
			rbit("cu_chroma_qp_offset_enabled_flag",                       1) -- u(1))
		end

		if get("deblocking_filter_override_enabled_flag") == 1 then
			rbit("deblocking_filter_override_flag",                        1) -- u(1))
		end

		if get("deblocking_filter_override_flag") == 1 then 
			rbit("slice_deblocking_filter_disabled_flag",                  1) -- u(1))
			if get("slice_deblocking_filter_disabled_flag") ~= 1 then 
				rexp("slice_beta_offset_div2"                              ) -- se(v))
				rexp("slice_tc_offset_div2"                                ) -- se(v))
			end
		end

		if get("pps_loop_filter_across_slices_enabled_flag")
		and (get("slice_sao_luma_flag") == 1 or get("slice_sao_chroma_flag") == 1
			or get("slice_deblocking_filter_disabled_flag") ~=1 ) then
			rbit("slice_loop_filter_across_slices_enabled_flag",           1) -- u(1))
		end
	end

	if get("tiles_enabled_flag") or get("entropy_coding_sync_enabled_flag") then 
		rexp("num_entry_point_offsets"                                 ) -- ue(v))
		if get("num_entry_point_offsets") > 0 then 
			rexp("offset_len_minus1"                                   ) -- ue(v))
			for i = 0, get("num_entry_point_offsets")-1 do
				rbit("entry_point_offset_minus1[i]",                   get("offset_len_minus1") + 1) -- u(v))
			end
		end
	end

	if get("slice_segment_header_extension_present_flag") == 1 then 
		rexp("slice_segment_header_extension_length"                   ) -- ue(v))
		for  i = 0, get("slice_segment_header_extension_length") - 1 do
			rbit("slice_segment_header_extension_data_byte[i]",        8) -- u(8))
		end
	end

	byte_alignment( )
end

NumDeltaPocs = {}
NumNegativePics = {}
NumPositivePics = {}
UsedByCurrPicS0 = {}
UsedByCurrPicS1 = {}
DeltaPocS0 = {}
DeltaPocS1 = {}
use_delta_flag = {}

function st_ref_pic_set( stRpsIdx ) 
print("st_ref_pic_set", stRpsIdx)

	UsedByCurrPicS0[stRpsIdx] = {}
	UsedByCurrPicS1[stRpsIdx] = {}
	DeltaPocS0[ stRpsIdx ] = {}
	DeltaPocS1[ stRpsIdx ] = {}

	if stRpsIdx ~= 0  then
		rbit("inter_ref_pic_set_prediction_flag",                     1) -- u(1))
	end
	
	if get("inter_ref_pic_set_prediction_flag") == 1 then 
		if stRpsIdx == get("num_short_term_ref_pic_sets") then
			rexp("delta_idx_minus1"                                   ) -- ue(v))
		end
		rbit("delta_rps_sign",                                        1) -- u(1))
		rexp("abs_delta_rps_minus1"                                   ) -- ue(v))

		local RefRpsIdx = stRpsIdx - (get("delta_idx_minus1") or 0 + 1)
	
		local used_by_curr_pic_flag = {}
		for j = 0, NumDeltaPocs[RefRpsIdx] do 
			rbit("used_by_curr_pic_flag[j]",                          1) -- u(1))
			used_by_curr_pic_flag[j] = get("used_by_curr_pic_flag[j]")
			if get("used_by_curr_pic_flag[j]") ~= 1 then
				rbit("use_delta_flag[j]",                             1) -- u(1))
				use_delta_flag[j] = get("use_delta_flag[j]")
			else
				use_delta_flag[j] = 1
			end
		end

		local deltaRps = ( 1 - 2 * get("delta_rps_sign")) * (get("abs_delta_rps_minus1") + 1 )
		local i = 0
		local j = NumPositivePics[RefRpsIdx] - 1
		while j >= 0 do
			local dPoc = DeltaPocS1[RefRpsIdx][j] + deltaRps
			if dPoc < 0 and use_delta_flag[NumNegativePics[RefRpsIdx]+j] == 1 then
				DeltaPocS0[stRpsIdx][i] = dPoc
				UsedByCurrPicS0[stRpsIdx][i] = used_by_curr_pic_flag[NumNegativePics[RefRpsIdx]+j]
				i = i + 1
			end
			j = j - 1
		end
		if deltaRps < 0 and use_delta_flag[NumDeltaPocs[RefRpsIdx]] == 1 then
			DeltaPocS0[stRpsIdx][i] = deltaRps
			UsedByCurrPicS0[stRpsIdx][i] = used_by_curr_pic_flag[NumDeltaPocs[RefRpsIdx]]
			i = i + 1
		end
		for j = 0, NumNegativePics[RefRpsIdx] - 1 do
			local dPoc = DeltaPocS0[RefRpsIdx][j] + deltaRps
			if dPoc < 0 and use_delta_flag[j] == 1 then
				DeltaPocS0[stRpsIdx][i] = dPoc
				UsedByCurrPicS0[stRpsIdx][i] = used_by_curr_pic_flag[j]
				i = i + 1
			end
		end
		NumNegativePics[stRpsIdx] = i					
		
		i = 0
		local j = NumNegativePics[RefRpsIdx] - 1
		while j >= 0 do
			local dPoc = DeltaPocS0[ RefRpsIdx ][ j ] + deltaRps
			if dPoc > 0 and use_delta_flag[ j ] == 1  then
				DeltaPocS1[ stRpsIdx ][ i ] = dPoc
				UsedByCurrPicS1[ stRpsIdx ][i] = used_by_curr_pic_flag[ j ]
				i = i + 1	
			end
			j = j - 1
		end
		if deltaRps > 0 and use_delta_flag[ NumDeltaPocs[ RefRpsIdx ] ] == 1 then
			DeltaPocS1[ stRpsIdx ][ i ] = deltaRps
			UsedByCurrPicS1[ stRpsIdx ][i] = used_by_curr_pic_flag[ NumDeltaPocs[ RefRpsIdx ] ]
			i = i + 1
		end
		for j = 0, NumPositivePics[ RefRpsIdx ] - 1 do
			dPoc = DeltaPocS1[ RefRpsIdx ][ j ] + deltaRps
			if dPoc > 0 and use_delta_flag[ NumNegativePics[ RefRpsIdx ] + j ]  == 1 then
				DeltaPocS1[ stRpsIdx ][ i ] = dPoc
				UsedByCurrPicS1[ stRpsIdx ][i] = used_by_curr_pic_flag[ NumNegativePics[ RefRpsIdx ] + j ] 
				i = i + 1
			end
		end
		NumPositivePics[stRpsIdx] = i
		NumDeltaPocs[stRpsIdx] = NumNegativePics[stRpsIdx] + NumPositivePics[stRpsIdx]

		-- print("ref", RefRpsIdx, NumDeltaPocs[RefRpsIdx], NumNegativePics[RefRpsIdx], NumPositivePics[RefRpsIdx])
		-- print("cur", stRpsIdx, NumDeltaPocs[stRpsIdx], NumNegativePics[stRpsIdx], NumPositivePics[stRpsIdx])
	else
		rexp("num_negative_pics"                                      ) -- ue(v))
		rexp("num_positive_pics"                                      ) -- ue(v))
		for  i = 0, get("num_negative_pics") - 1  do 
			rexp("delta_poc_s0_minus1[i]"                             ) -- ue(v))
			rbit("used_by_curr_pic_s0_flag[i]",                       1) -- u(1))
			
			UsedByCurrPicS0[stRpsIdx][i] = get("used_by_curr_pic_s0_flag[i]")
			if i == 0 then
				DeltaPocS0[stRpsIdx][i] = -(get("delta_poc_s0_minus1[i]") + 1 )
			else
				DeltaPocS0[stRpsIdx][i] = DeltaPocS0[stRpsIdx][i-1]-(get("delta_poc_s0_minus1[i]") + 1 )
			end
		end
		for i = 0, get("num_positive_pics") - 1 do 
			rexp("delta_poc_s1_minus1[i]"                             ) -- ue(v))
			rbit("used_by_curr_pic_s1_flag[i]",                       1) -- u(1))
			
			UsedByCurrPicS1[stRpsIdx][i] = get("used_by_curr_pic_s1_flag[i]")
			if i == 0 then
				DeltaPocS1[stRpsIdx][i] = -(get("delta_poc_s1_minus1[i]") + 1 )
			else
				DeltaPocS1[stRpsIdx][i] = DeltaPocS1[stRpsIdx][i-1]-(get("delta_poc_s1_minus1[i]") + 1 )
			end
		end

		NumNegativePics[stRpsIdx] = get("num_negative_pics")
		NumPositivePics[stRpsIdx] = get("num_positive_pics")
		NumDeltaPocs[stRpsIdx] = NumNegativePics[stRpsIdx] + NumPositivePics[stRpsIdx]
	end
end

--function ref_pic_lists_modification( ) 
--	rbit("ref_pic_list_modification_flag_l0",                          1) -- u(1))
--	if ( ref_pic_list_modification_flag_l0 ) == true then
--	for  i = 0; i <= num_ref_idx_l0_active_minus1; i++  do
--	rbit("list_entry_l0[i]",                                           v) -- u(v))
--	if ( slice_type = = B ) == true then 
--	rbit("ref_pic_list_modification_flag_l1",                          1) -- u(1))
--	if ( ref_pic_list_modification_flag_l1 ) == true then
--	for  i = 0; i <= num_ref_idx_l1_active_minus1; i++  do
--	rbit("list_entry_l1[i]",                                           v) -- u(v))
--	end
--	end
--	                                              
--function pred_weight_table( ) 
--	rexp("luma_log2_weight_denom"                                      ) -- ue(v))
--	if ( ChromaArrayType != 0 ) == true then
--	rexp("delta_chroma_log2_weight_denom"                              ) -- se(v))
--	for  i = 0; i <= num_ref_idx_l0_active_minus1; i++  do
--	rbit("luma_weight_l0_flag[i]",                                     1) -- u(1))
--	if ( ChromaArrayType != 0 ) == true then
--	for  i = 0; i <= num_ref_idx_l0_active_minus1; i++  do
--	rbit("chroma_weight_l0_flag[i]",                                   1) -- u(1))
--	for  i = 0; i <= num_ref_idx_l0_active_minus1; i++  do 
--	if ( luma_weight_l0_flag[i] ) == true then 
--	rexp("delta_luma_weight_l0[i]"                                     ) -- se(v))
--	rexp("luma_offset_l0[i]"                                           ) -- se(v))
--	end
--	if ( chroma_weight_l0_flag[i] ) == true then
--	for  j = 0; j < 2; j++  do 
--	rexp("delta_chroma_weight_l0[i][j]"                                ) -- se(v))
--	rexp("delta_chroma_offset_l0[i][j]"                                ) -- se(v))
--	end
--	end
--	if ( slice_type = = B ) == true then 
--	for  i = 0; i <= num_ref_idx_l1_active_minus1; i++  do
--	rbit("luma_weight_l1_flag[i]",                                     1) -- u(1))
--	if ( ChromaArrayType != 0 ) == true then
--	for  i = 0; i <= num_ref_idx_l1_active_minus1; i++  do
--	rbit("chroma_weight_l1_flag[i]",                                   1) -- u(1))
--	for  i = 0; i <= num_ref_idx_l1_active_minus1; i++  do 
--	if ( luma_weight_l1_flag[i] ) == true then 
--	rexp("delta_luma_weight_l1[i]"                                     ) -- se(v))
--	rexp("luma_offset_l1[i]"                                           ) -- se(v))
--	end
--	if ( chroma_weight_l1_flag[i] ) == true then
--	for  j = 0; j < 2; j++  do 
--	rexp("delta_chroma_weight_l1[i][j]"                                ) -- se(v))
--	rexp("delta_chroma_offset_l1[i][j]"                                ) -- se(v))
--	end
--	end
--	end
--	end
--
--                                             
--function slice_segment_data( ) 
--	                                              do 
--	coding_tree_unit( )
--	rexp("end_of_slice_segment_flag"                                              ) -- ae(v))
--	CtbAddrInTs++                                              	CtbAddrInRs  CtbAddrTsToRs[CtbAddrInTs]
--	if ( !end_of_slice_segment_flag and ( ( tiles_enabled_flag and TileId[CtbAddrInTs] != TileId[CtbAddrInTs ? 1] ) or ( entropy_coding_sync_enabled_flag and ( CtbAddrInTs % PicWidthInCtbsY = = 0 or TileId[CtbAddrInTs] != TileId[CtbAddrRsToTs[CtbAddrInRs ? 1] ] ) ) ) ) == true then 
--	end_of_subset_one_bit -- equal to 1                                               ae(v)
--	byte_alignment( )
--	end
--	end while( !end_of_slice_segment_flag )
--	end
--
--function coding_tree_unit( ) 
--	                                              	xCtb  ( CtbAddrInRs % PicWidthInCtbsY ) << CtbLog2SizeY
--	yCtb  ( CtbAddrInRs / PicWidthInCtbsY ) << CtbLog2SizeY
--	if ( slice_sao_luma_flag or slice_sao_chroma_flag ) == true then
--	sao( xCtb >> CtbLog2SizeY, yCtb >> CtbLog2SizeY )
--	coding_quadtree( xCtb, yCtb, CtbLog2SizeY, 0 )
--	end
--	
--	
--function sao( rx, ry )
--	                                              	if ( rx > 0 ) == true then 
--	leftCtbInSliceSeg  CtbAddrInRs > SliceAddrRs
--	leftCtbInTile = TileId[CtbAddrInTs] =  TileId[CtbAddrRsToTs[CtbAddrInRs ? 1]]
--	if ( leftCtbInSliceSeg and leftCtbInTile ) == true then
--	rexp("sao_merge_left_flag"                                              ) -- ae(v))
--	end
--	if ( ry > 0 and !sao_merge_left_flag ) == true then 
--	upCtbInSliceSeg = ( CtbAddrInRs ? PicWidthInCtbsY ) > SliceAddrRs
--	upCtbInTile = TileId[CtbAddrInTs] =  TileId[CtbAddrRsToTs[CtbAddrInRs ? PicWidthInCtbsY]]
--	if ( upCtbInSliceSeg and upCtbInTile ) == true then
--	rexp("sao_merge_up_flag"                                              ) -- ae(v))
--	end
--	if ( !sao_merge_up_flag and !sao_merge_left_flag ) == true then
--	for  cIdx = 0; cIdx < ( ChromaArrayType != 0 ? 3 : 1 ); cIdx++  do
--	if ( ( slice_sao_luma_flag and cIdx = = 0 ) or ( slice_sao_chroma_flag and cIdx > 0 ) ) == true then 
--	if ( cIdx = = 0 ) == true then
--	rexp("sao_type_idx_luma"                                              ) -- ae(v))
--	elseif ( cIdx = = 1 ) == true then
--	rexp("sao_type_idx_chroma"                                              ) -- ae(v))
--	if ( SaoTypeIdx[cIdx][rx][ry] != 0 ) == true then 
--	for  i = 0; i < 4; i++  do
--	rexp("sao_offset_abs[cIdx][rx][ry][i]"                                              ) -- ae(v))
--	if ( SaoTypeIdx[cIdx][rx][ry] = = 1 ) == true then 
--	for  i = 0; i < 4; i++  do
--	if ( sao_offset_abs[cIdx][rx][ry][i] != 0 ) == true then
--	rexp("sao_offset_sign[cIdx][rx][ry][i]"                                              ) -- ae(v))
--	rexp("sao_band_position[cIdx][rx][ry]"                                              ) -- ae(v))
--	elseif 
--	if ( cIdx = = 0 ) == true then
--	rexp("sao_eo_class_luma"                                              ) -- ae(v))
--	if ( cIdx = = 1 ) == true then
--	rexp("sao_eo_class_chroma"                                              ) -- ae(v))
--	end
--	end
--	end
--	end
--	   
--function coding_quadtree( x0, y0, log2CbSize, cqtDepth ) 
--	                                              	if ( x0 + ( 1 << log2CbSize ) <= pic_width_in_luma_samples and y0 + ( 1 << log2CbSize ) <= pic_height_in_luma_samples and log2CbSize > MinCbLog2SizeY ) == true then
--	rexp("split_cu_flag[x0][y0]"                                              ) -- ae(v))
--	if ( cu_qp_delta_enabled_flag and log2CbSize >= Log2MinCuQpDeltaSize ) == true then 
--	IsCuQpDeltaCoded  0
--	CuQpDeltaVal  0
--	end
--	if ( cu_chroma_qp_offset_enabled_flag and log2CbSize >= Log2MinCuChromaQpOffsetSize ) == true then
--	IsCuChromaQpOffsetCoded  0
--	if ( split_cu_flag[x0][y0] ) == true then 
--	x1  x0 + ( 1 << ( log2CbSize ? 1 ) )
--	y1  y0 + ( 1 << ( log2CbSize ? 1 ) )
--	coding_quadtree( x0, y0, log2CbSize ? 1, cqtDepth + 1 )
--	if ( x1 < pic_width_in_luma_samples ) == true then
--	coding_quadtree( x1, y0, log2CbSize ? 1, cqtDepth + 1 )
--	if ( y1 < pic_height_in_luma_samples ) == true then
--	coding_quadtree( x0, y1, log2CbSize ? 1, cqtDepth + 1 )
--	if ( x1 < pic_width_in_luma_samples and y1 < pic_height_in_luma_samples ) == true then
--	coding_quadtree( x1, y1, log2CbSize ? 1, cqtDepth + 1 )
--	elseif
--	coding_unit( x0, y0, log2CbSize )
--	end
--
--function coding_unit( x0, y0, log2CbSize ) 
--	                                              	if ( transquant_bypass_enabled_flag ) == true then
--	rexp("cu_transquant_bypass_flag"                                              ) -- ae(v))
--	if ( slice_type != I ) == true then
--	rexp("cu_skip_flag[x0][y0]"                                              ) -- ae(v))
--	nCbS  ( 1 << log2CbSize )
--	if ( cu_skip_flag[x0][y0] ) == true then
--	prediction_unit( x0, y0, nCbS, nCbS )
--	else 
--	if ( slice_type != I ) == true then
--	rexp("pred_mode_flag"                                              ) -- ae(v))
--	if ( CuPredMode[x0][y0] != MODE_INTRA or log2CbSize = = MinCbLog2SizeY ) == true then
--	rexp("part_mode"                                              ) -- ae(v))
--	if ( CuPredMode[x0][y0] = = MODE_INTRA ) == true then 
--	if ( PartMode = = PART_2Nx2N and pcm_enabled_flag and log2CbSize >= Log2MinIpcmCbSizeY and log2CbSize <= Log2MaxIpcmCbSizeY ) == true then
--	rexp("pcm_flag[x0][y0]"                                              ) -- ae(v))
--	if ( pcm_flag[x0][y0] ) == true then 
--	while( !byte_aligned( ) )
--	pcm_alignment_zero_bit                                              f(1)
--	pcm_sample( x0, y0, log2CbSize )
--	elseif 
--	pbOffset = ( PartMode =  PART_NxN ) ? ( nCbS / 2 ) : nCbS
--	for  j = 0; j < nCbS; j = j + pbOffset  do
--	for  i = 0; i < nCbS; i = i + pbOffset  do
--	prev_intra_luma_pred_flag[x0 + i][y0 + j]                                              ae(v)
--	for  j = 0; j < nCbS; j = j + pbOffset  do
--	for  i = 0; i < nCbS; i = i + pbOffset  do
--	if ( prev_intra_luma_pred_flag[x0 + i][y0 + j] ) == true then
--	mpm_idx[x0 + i][y0 + j]                                              ae(v)
--	else
--	rem_intra_luma_pred_mode[x0 + i][y0 + j]                                              ae(v)
--	if ( ChromaArrayType = = 3 ) == true then
--	for  j = 0; j < nCbS; j = j + pbOffset  do
--	for  i = 0; i < nCbS; i = i + pbOffset  do
--	intra_chroma_pred_mode[x0 + i][y0 + j]                                              ae(v)
--	elseif ( ChromaArrayType != 0 ) == true then
--	rexp("intra_chroma_pred_mode[x0][y0]"                                              ) -- ae(v))
--	end
--	elseif 
--	if ( PartMode = = PART_2Nx2N ) == true then
--	prediction_unit( x0, y0, nCbS, nCbS )
--	elseif ( PartMode = = PART_2NxN ) == true then 
--	prediction_unit( x0, y0, nCbS, nCbS / 2 )
--	prediction_unit( x0, y0 + ( nCbS / 2 ), nCbS, nCbS / 2 )
--	elseif ( PartMode = = PART_Nx2N ) == true then 
--	prediction_unit( x0, y0, nCbS / 2, nCbS )
--	prediction_unit( x0 + ( nCbS / 2 ), y0, nCbS / 2, nCbS )
--	elseif ( PartMode = = PART_2NxnU ) == true then 
--	prediction_unit( x0, y0, nCbS, nCbS / 4 )
--	prediction_unit( x0, y0 + ( nCbS / 4 ), nCbS, nCbS * 3 / 4 )
--	elseif ( PartMode = = PART_2NxnD ) == true then 
--	prediction_unit( x0, y0, nCbS, nCbS * 3 / 4 )
--	prediction_unit( x0, y0 + ( nCbS * 3 / 4 ), nCbS, nCbS / 4 )
--	elseif ( PartMode = = PART_nLx2N ) == true then 
--	prediction_unit( x0, y0, nCbS / 4, nCbS )
--	prediction_unit( x0 + ( nCbS / 4 ), y0, nCbS * 3 / 4, nCbS )
--	elseif ( PartMode = = PART_nRx2N ) == true then 
--	prediction_unit( x0, y0, nCbS * 3 / 4, nCbS )
--	prediction_unit( x0 + ( nCbS * 3 / 4 ), y0, nCbS / 4, nCbS )
--	elseif  -- PART_NxN 
--	prediction_unit( x0, y0, nCbS / 2, nCbS / 2 )
--	prediction_unit( x0 + ( nCbS / 2 ), y0, nCbS / 2, nCbS / 2 )
--	prediction_unit( x0, y0 + ( nCbS / 2 ), nCbS / 2, nCbS / 2 )
--	prediction_unit( x0 + ( nCbS / 2 ), y0 + ( nCbS / 2 ), nCbS / 2, nCbS / 2 )
--	end
--	end
--	if ( !pcm_flag[x0][y0] ) == true then 
--	if ( CuPredMode[x0][y0] != MODE_INTRA and !( PartMode = = PART_2Nx2N and merge_flag[x0][y0] ) ) == true then
--	rexp("rqt_root_cbf"                                              ) -- ae(v))
--	if ( rqt_root_cbf ) == true then 
--	MaxTrafoDepth = ( CuPredMode[x0][y0] =  MODE_INTRA ? ( max_transform_hierarchy_depth_intra + IntraSplitFlag ) : max_transform_hierarchy_depth_inter )
--transform_tree( x0, y0, x0, y0, log2CbSize, 0, 0 )
--	end
--	end
--	end
--	end
--
--function  prediction_unit( x0, y0, nPbW, nPbH ) 
--	                                              	if ( cu_skip_flag[x0][y0] ) == true then 
--	if ( MaxNumMergeCand > 1 ) == true then
--	rexp("merge_idx[x0][y0]"                                              ) -- ae(v))
--	elseif  -- MODE_INTER 
--	rexp("merge_flag[x0][y0]"                                              ) -- ae(v))
--	if ( merge_flag[x0][y0] ) == true then 
--	if ( MaxNumMergeCand > 1 ) == true then
--	rexp("merge_idx[x0][y0]"                                              ) -- ae(v))
--	elseif 
--	if ( slice_type = = B ) == true then
--	rexp("inter_pred_idc[x0][y0]"                                              ) -- ae(v))
--	if ( inter_pred_idc[x0][y0] != PRED_L1 ) == true then 
--	if ( num_ref_idx_l0_active_minus1 > 0 ) == true then
--	rexp("ref_idx_l0[x0][y0]"                                              ) -- ae(v))
--	mvd_coding( x0, y0, 0 )
--	rexp("mvp_l0_flag[x0][y0]"                                              ) -- ae(v))
--	end
--	if ( inter_pred_idc[x0][y0] != PRED_L0 ) == true then 
--	if ( num_ref_idx_l1_active_minus1 > 0 ) == true then
--	rexp("ref_idx_l1[x0][y0]"                                              ) -- ae(v))
--	if ( mvd_l1_zero_flag and inter_pred_idc[x0][y0] = = PRED_BI ) == true then 
--	MvdL1[x0][y0][0]  0
--	MvdL1[x0][y0][1]  0
--	elseif
--	mvd_coding( x0, y0, 1 )
--	rexp("mvp_l1_flag[x0][y0]"                                              ) -- ae(v))
--	end
--	end
--	end
--	end
--
--function  pcm_sample( x0, y0, log2CbSize ) 
--	                                              	for  i = 0; i < 1 << ( log2CbSize << 1 ); i++  do
--	rbit("pcm_sample_luma[i]",                                              v) -- u(v))
--	if ( ChromaArrayType != 0 ) == true then
--	for  i = 0; i < ( ( 2 << ( log2CbSize << 1 ) ) / ( SubWidthC * SubHeightC ) ); i++  do
--	rbit("pcm_sample_chroma[i]",                                              v) -- u(v))
--	end
--
--function  transform_tree( x0, y0, xBase, yBase, log2TrafoSize, trafoDepth, blkIdx ) 
--	                                              	if ( log2TrafoSize <= MaxTbLog2SizeY and log2TrafoSize > MinTbLog2SizeY and trafoDepth < MaxTrafoDepth and !( IntraSplitFlag and ( trafoDepth = = 0 ) ) ) == true then
--	rexp("split_transform_flag[x0][y0][trafoDepth]"                                              ) -- ae(v))
--	if ( ( log2TrafoSize > 2 and ChromaArrayType != 0 ) or ChromaArrayType = = 3 ) == true then 
--	if ( trafoDepth = = 0 or cbf_cb[xBase][yBase][trafoDepth ? 1] ) == true then 
--	rexp("cbf_cb[x0][y0][trafoDepth]"                                              ) -- ae(v))
--	if ( ChromaArrayType = = 2 and ( !split_transform_flag[x0][y0][trafoDepth] or log2TrafoSize = = 3 ) ) == true then
--cbf_cb[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth]
--	ae(v)
--	end
--	if ( trafoDepth = = 0 or cbf_cr[xBase][yBase][trafoDepth ? 1] ) == true then 
--	rexp("cbf_cr[x0][y0][trafoDepth]"                                              ) -- ae(v))
--	if ( ChromaArrayType = = 2 and ( !split_transform_flag[x0][y0][trafoDepth] or log2TrafoSize = = 3 ) ) == true then
--cbf_cr[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth]
--	ae(v)
--	end
--	end
--	if ( split_transform_flag[x0][y0][trafoDepth] ) == true then 
--	x1  x0 + ( 1 << ( log2TrafoSize ? 1 ) )
--	y1  y0 + ( 1 << ( log2TrafoSize ? 1 ) )
--transform_tree( x0, y0, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 0 )
--transform_tree( x1, y0, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 1 )
--transform_tree( x0, y1, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 2 )
--transform_tree( x1, y1, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 3 )
--	elseif 
--	if ( CuPredMode[x0][y0] = = MODE_INTRA or trafoDepth != 0 or cbf_cb[x0][y0][trafoDepth] or cbf_cr[x0][y0][trafoDepth] or ( ChromaArrayType = = 2 and ( cbf_cb[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth] or cbf_cr[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth] ) ) ) == true then
--	rexp("cbf_luma[x0][y0][trafoDepth]"                                              ) -- ae(v))
--transform_unit( x0, y0, xBase, yBase, log2TrafoSize, trafoDepth, blkIdx )
--	end
--	end
--	
--function mvd_coding( x0, y0, refList ) 
--	                                              abs_mvd_greater0_flag[0]
--	ae(v)
--	rexp("abs_mvd_greater0_flag[1]"                                              ) -- ae(v))
--	if ( abs_mvd_greater0_flag[0] ) == true then
--	rexp("abs_mvd_greater1_flag[0]"                                              ) -- ae(v))
--	if ( abs_mvd_greater0_flag[1] ) == true then
--	rexp("abs_mvd_greater1_flag[1]"                                              ) -- ae(v))
--	if ( abs_mvd_greater0_flag[0] ) == true then 
--	if ( abs_mvd_greater1_flag[0] ) == true then
--	rexp("abs_mvd_minus2[0]"                                              ) -- ae(v))
--	rexp("mvd_sign_flag[0]"                                              ) -- ae(v))
--	end
--	if ( abs_mvd_greater0_flag[1] ) == true then 
--	if ( abs_mvd_greater1_flag[1] ) == true then
--	rexp("abs_mvd_minus2[1]"                                              ) -- ae(v))
--	rexp("mvd_sign_flag[1]"                                              ) -- ae(v))
--	end
--	end
--
--function transform_unit( x0, y0, xBase, yBase, log2TrafoSize, trafoDepth, blkIdx ) 
--	                                              	log2TrafoSizeC = Max( 2, log2TrafoSize ? ( ChromaArrayType =  3 ? 0 : 1 ) )
--	cbfDepthC = trafoDepth ? ( ChromaArrayType != 3 and log2TrafoSize =  2 ? 1 : 0 )
--	xC = ( ChromaArrayType != 3 and log2TrafoSize =  2 ) ? xBase : x0
--	yC = ( ChromaArrayType != 3 and log2TrafoSize =  2 ) ? yBase : y0
--	cbfLuma  cbf_luma[x0][y0][trafoDepth]
--	cbfChroma = cbf_cb[xC][yC][cbfDepthC] or cbf_cr[xC][yC][cbfDepthC] or ( ChromaArrayType =  2 and ( cbf_cb[xC][yC + ( 1 << log2TrafoSizeC )][cbfDepthC] or cbf_cr[xC][yC + ( 1 << log2TrafoSizeC )][cbfDepthC] ) )
--	if ( cbfLuma or cbfChroma ) == true then 
--	if ( cu_qp_delta_enabled_flag and !IsCuQpDeltaCoded ) == true then 
--	rexp("cu_qp_delta_abs"                                              ) -- ae(v))
--	if ( cu_qp_delta_abs ) == true then
--	rexp("cu_qp_delta_sign_flag"                                              ) -- ae(v))
--	end
--	if ( cu_chroma_qp_offset_enabled_flag and cbfChroma and !cu_transquant_bypass_flag and !IsCuChromaQpOffsetCoded ) == true then 
--	rexp("cu_chroma_qp_offset_flag"                                              ) -- ae(v))
--	if ( cu_chroma_qp_offset_flag and chroma_qp_offset_list_len_minus1 > 0 ) == true then
--	rexp("cu_chroma_qp_offset_idx"                                              ) -- ae(v))
--	end
--	if ( cbfLuma ) == true then
--	residual_coding( x0, y0, log2TrafoSize, 0 )
--	if ( log2TrafoSize > 2 or ChromaArrayType = = 3 ) == true then 
--	if ( cross_component_prediction_enabled_flag and cbfLuma and ( CuPredMode[x0][y0] = = MODE_INTER or intra_chroma_pred_mode[x0][y0] = = 4 ) ) == true then
--	cross_comp_pred( x0, y0, 0 )
--	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
--	if ( cbf_cb[x0][y0 + ( tIdx << log2TrafoSizeC )][trafoDepth] ) == true then
--	residual_coding( x0, y0 + ( tIdx << log2TrafoSizeC ), log2TrafoSizeC, 1 )
--	if ( cross_component_prediction_enabled_flag and cbfLuma and ( CuPredMode[x0][y0] = = MODE_INTER or intra_chroma_pred_mode[x0][y0] = = 4 ) ) == true then
--	cross_comp_pred( x0, y0, 1 )
--	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
--	if ( cbf_cr[x0][y0 + ( tIdx << log2TrafoSizeC )][trafoDepth] ) == true then
--	residual_coding( x0, y0 + ( tIdx << log2TrafoSizeC ), log2TrafoSizeC, 2 )
--		elseif ( blkIdx = = 3 ) == true then 
--	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
--	if ( cbf_cb[xBase][yBase + ( tIdx << log2TrafoSizeC )][trafoDepth ? 1] ) == true then
--	residual_coding( xBase, yBase + ( tIdx << log2TrafoSizeC ), log2TrafoSize, 1 )
--	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
--	if ( cbf_cr[xBase][yBase + ( tIdx << log2TrafoSizeC )][trafoDepth ? 1] ) == true then
--	residual_coding( xBase, yBase + ( tIdx << log2TrafoSizeC ), log2TrafoSize, 2 )
--	end
--	end
--	end
--	                                              
--function residual_coding( x0, y0, log2TrafoSize, cIdx ) 
--	                                              	if ( transform_skip_enabled_flag and !cu_transquant_bypass_flag and ( log2TrafoSize <= Log2MaxTransformSkipSize ) ) == true then
--	rexp("transform_skip_flag[x0][y0][cIdx]"                                              ) -- ae(v))
--	if ( CuPredMode[x0][y0] = = MODE_INTER and explicit_rdpcm_enabled_flag and ( transform_skip_flag[x0][y0][cIdx] or cu_transquant_bypass_flag ) ) == true then 
--	rexp("explicit_rdpcm_flag[x0][y0][cIdx]"                                              ) -- ae(v))
--	if ( explicit_rdpcm_flag[x0][y0][cIdx] ) == true then
--	rexp("explicit_rdpcm_dir_flag[x0][y0][cIdx]"                                              ) -- ae(v))
--	end
--	rexp("last_sig_coeff_x_prefix"                                              ) -- ae(v))
--	rexp("last_sig_coeff_y_prefix"                                              ) -- ae(v))
--	if ( last_sig_coeff_x_prefix > 3 ) == true then
--	rexp("last_sig_coeff_x_suffix"                                              ) -- ae(v))
--	if ( last_sig_coeff_y_prefix > 3 ) == true then
--	rexp("last_sig_coeff_y_suffix"                                              ) -- ae(v))
--	lastScanPos  16
--	lastSubBlock  ( 1 << ( log2TrafoSize ? 2 ) ) * ( 1 << ( log2TrafoSize ? 2 ) ) ? 1
--	escapeDataPresent  0
--	do                                               	if ( lastScanPos = = 0 ) == true then 
--	lastScanPos  16
--	lastSubBlock? ?                                              	end
--	lastScanPos? ?                                              	xS  ScanOrder[log2TrafoSize ? 2][scanIdx][lastSubBlock][0]
--	yS  ScanOrder[log2TrafoSize ? 2][scanIdx][lastSubBlock][1]
--	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][lastScanPos][0]
--	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][lastScanPos][1]
--	end while( ( xC != LastSignificantCoeffX ) or ( yC != LastSignificantCoeffY ) )
--	for  i = lastSubBlock; i >= 0; i? ?  do 
--	xS  ScanOrder[log2TrafoSize ? 2][scanIdx][i][0]
--	yS  ScanOrder[log2TrafoSize ? 2][scanIdx][i][1]
--	inferSbDcSigCoeffFlag  0
--	if ( ( i < lastSubBlock ) and ( i > 0 ) ) == true then 
--	rexp("coded_sub_block_flag[xS][yS]"                                              ) -- ae(v))
--	inferSbDcSigCoeffFlag  1
--	end
--	for  n = ( i = = lastSubBlock ) ? lastScanPos ? 1 : 15; n >= 0; n? ?  do 
--	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
--	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
--	if ( coded_sub_block_flag[xS][yS] and ( n > 0 or !inferSbDcSigCoeffFlag ) ) == true then 
--	rexp("sig_coeff_flag[xC][yC]"                                              ) -- ae(v))
--	if ( sig_coeff_flag[xC][yC] ) == true then
--	inferSbDcSigCoeffFlag  0
--	end
--	end
--	firstSigScanPos  16
--	lastSigScanPos  ?1
--	numGreater1Flag  0
--	lastGreater1ScanPos  ?1
--	for  n = 15; n >= 0; n? ?  do 
--	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
--	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
--	if ( sig_coeff_flag[xC][yC] ) == true then 
--	if ( numGreater1Flag < 8 ) == true then 
--	rexp("coeff_abs_level_greater1_flag[n]"                                              ) -- ae(v))
--	numGreater1Flag++                                              	if ( coeff_abs_level_greater1_flag[n] and lastGreater1ScanPos = = ?1 ) == true then
--	lastGreater1ScanPos  n
--	elseif ( coeff_abs_level_greater1_flag[n] ) == true then
--	escapeDataPresent  1
--	elseif
--	escapeDataPresent  1
--	if ( lastSigScanPos = = ?1 ) == true then
--	lastSigScanPos  n
--	firstSigScanPos  n
--	end
--	end
--	if ( cu_transquant_bypass_flag or ( CuPredMode[x0][y0] = = MODE_INTRA and implicit_rdpcm_enabled_flag and transform_skip_flag[x0][y0][cIdx] and ( predModeIntra = = 10 or predModeIntra = = 26 ) ) or explicit_rdpcm_flag[x0][y0][cIdx] ) == true then
--	signHidden  0
--	else
--	signHidden  lastSigScanPos ? firstSigScanPos > 3
--	if ( lastGreater1ScanPos != ?1 ) == true then 
--	rexp("coeff_abs_level_greater2_flag[lastGreater1ScanPos]"                                              ) -- ae(v))
--	if ( coeff_abs_level_greater2_flag[lastGreater1ScanPos] ) == true then
--	escapeDataPresent  1
--	end
--	for  n = 15; n >= 0; n? ?  do 
--	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
--	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
--	if ( sig_coeff_flag[xC][yC] and ( !sign_data_hiding_enabled_flag or !signHidden or ( n != firstSigScanPos ) ) ) == true then
--	rexp("coeff_sign_flag[n]"                                              ) -- ae(v))
--	end
--	numSigCoeff  0
--	sumAbsLevel  0
--	for  n = 15; n >= 0; n? ?  do 
--	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
--	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
--	if ( sig_coeff_flag[xC][yC] ) == true then 
--	baseLevel  1 + coeff_abs_level_greater1_flag[n] + coeff_abs_level_greater2_flag[n]
--	if ( baseLevel = = ( ( numSigCoeff < 8 ) ? ( (n = = lastGreater1ScanPos) ? 3 : 2 ) : 1 ) ) == true then
--	rexp("coeff_abs_level_remaining[n]"                                              ) -- ae(v))
--	TransCoeffLevel[x0][y0][cIdx][xC][yC]  ( coeff_abs_level_remaining[n] + baseLevel ) * ( 1 ? 2 * coeff_sign_flag[n] )
--	if ( sign_data_hiding_enabled_flag and signHidden ) == true then 
--	sumAbsLevel + ( coeff_abs_level_remaining[n] + baseLevel )
--	if ( ( n = = firstSigScanPos ) and ( ( sumAbsLevel % 2 ) = = 1 ) ) == true then
--	TransCoeffLevel[x0][y0][cIdx][xC][yC]  ?TransCoeffLevel[x0][y0][cIdx][xC][yC]
--	end
--	numSigCoeff++                                              	end
--	end
--	end
--	end
--
--function cross_comp_pred( x0, y0, c ) 
--	log2_res_scale_abs_plus1[c] ae(v)
--	if ( log2_res_scale_abs_plus1[c] != 0 ) == true then
--	rexp("res_scale_sign_flag[c]"                                              ) -- ae(v))
--	end
--	                                              
--	

















function sei_payload(payloadType, payloadSize)
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
	
	rbyte("sei payload", payloadSize - (cur() - begin))
	
	if byte_aligned() == false then
		rbsp_trailing_bits()
	end
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

function nal_unit_264(rbsp, NumBytesInNALunit)

	local total = 1
	local ofs
	while true do
		ofs = math.min(fstr("00 00 03", false), NumBytesInNALunit - total)
		
		if ofs >= NumBytesInNALunit - total then 
			tbyte("rbsp end", ofs, rbsp)
			break
		else
			tbyte("rbsp", ofs+2, rbsp)
			rbyte("dummy", 1)
			total = total + ofs + 2 + 1
		end
	end
end

function nal_unit(rbsp, NumBytesInNALunit)
	local total
	local ofs

	total = nal_unit_header()

	while true do
		ofs = math.min(fstr("00 00 03", false), NumBytesInNALunit - total)
		if ofs >= NumBytesInNALunit - total then 
			tbyte("rbsp end", ofs, rbsp)
			break
		else
			tbyte("rbsp", ofs+2, rbsp)
			rbyte("dummy", 1)
			total = total + ofs + 2 + 1
		end
	end

	nal_unit_payload(rbsp)
end

function nal_unit_header()
	cbit("forbidden_zero_bit",    1, 0) -- f(1)
	rbit("nal_unit_type",         6) -- u(6)
	rbit("nuh_layer_id",          6) -- u(6)
	rbit("nuh_temporal_id_plus1", 3) -- u(3)
	return 2
end

function nal_unit_payload(rbsp)

	local nal_unit_type = get("nal_unit_type")
	
	local file = swap(rbsp)

	if     nal_unit_type == TRAIL_N    then print("TRAIL_N")     slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == TRAIL_R    then print("TRAIL_R")     slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == TSA_N      then print("TSA_N")       slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == TSA_R      then print("TSA_R")       slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == STSA_N     then print("STSA_N")      slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == STSA_R     then print("STSA_R")      slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RADL_N     then print("RADL_N")      slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RADL_R     then print("RADL_R")      slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RASL_N     then print("RASL_N")      slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RASL_R     then print("RASL_R")      slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RSV_VCL_N  then print("RSV_VCL_N10") slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RSV_VCL_N  then print("RSV_VCL_N12") slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RSV_VCL_N  then print("RSV_VCL_N14") slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RSV_VCL_R  then print("RSV_VCL_R11") slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RSV_VCL_R  then print("RSV_VCL_R13") slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == RSV_VCL_R  then print("RSV_VCL_R15") slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == BLA_W_LP   then print("BLA_W_LP")    slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == BLA_W_RADL then print("BLA_W_RADL")  slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == BLA_N_LP   then print("BLA_N_LP")    slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == IDR_W_RADL then print("IDR_W_RADL")  slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == IDR_N_LP   then print("IDR_N_LP")    slice_segment_layer_rbsp(nal_unit_type)
    elseif nal_unit_type == CRA_NUT    then print("CRA_NUT")     slice_segment_layer_rbsp(nal_unit_type)
	elseif nal_unit_type == 32 then
		video_parameter_set_rbsp()
	elseif nal_unit_type == 33 then
		seq_parameter_set_rbsp()
	elseif nal_unit_type == 34 then
		pic_parameter_set_rbsp()
	elseif nal_unit_type == 35 then
		access_unit_delimiter_rbsp()
	elseif nal_unit_type == 39
	or     nal_unit_type == 40 then
		sei_rbsp()
	end
	
	-- とりあえず余ったデータを読み捨てる
	seek(get_size())

	swap(file)
end

function byte_stream_nal_unit(rbsp, NumBytesInNALunit)
print("------------"..hexstr(cur()).."------------")

	local begin = cur()

	while lbyte(3) ~= 0x000001
	and lbyte(4) ~= 0x00000001 do
		cbyte("leading_zero_8bits",                     1, 0)
	end
	
	if lbyte(3) ~= 0x000001 then
		cbyte("zero_byte",                              1, 0)
	end
	cbyte("start_code_prefix_one_3bytes",               3, 0x000001)
	
	NumBytesInNALunit = math.min(fstr("00 00 00", false), fstr("00 00 01", false), NumBytesInNALunit)
	nal_unit(rbsp, NumBytesInNALunit)
	
	while more_data_in_byte_stream()
	and lbyte(3) ~= 0x000001
	and lbyte(4) ~= 0x00000001 do
		cbit("trailing_zero_8bits",                     8, 0)
	end
	
	return cur() - begin
end

function h264_byte_stream(max_length)
	local rbsp = stream:new(1024*1024*3)
	rbsp:enable_print(false)

	reset_initial_values()

	local total_size = 0;
	while total_size < max_length do
		total_size = total_size + byte_stream_nal_unit(rbsp, max_length-total_size)
	end
end

open(__stream_path__)
print_status()
enable_print(false)
stdout_to_file(false)
h264_byte_stream(get_size())


