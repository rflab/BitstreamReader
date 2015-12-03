-- aac解析
-- ストリーム解析
local syncword = 0xfff
local ID_SCE = 0x0 -- SCE single_channel_element()
local ID_CPE = 0x1 -- CPE channel_pair_element()
local ID_CCE = 0x2 -- CCE coupling_channel_element()
local ID_LFE = 0x3 -- LFE lfe_channel_element()
local ID_DSE = 0x4 -- DSE data_stream_element()
local ID_PCE = 0x5 -- PCE program_config_element()
local ID_FIL = 0x6 -- FIL fill_element()
local ID_END = 0x7

local adts_begin = 0

function byte_alignment()
	local b = select(2, cur())
	if b ~= 0 then
		rbit("byte_alignment_bit", 8-b)
	end
end

function adts_sequence(size)
	-- enable_print(true)
	while cur() < size do
		check_progress(false)
		if lbit(12) == syncword then
			adts_frame()
		else
			byte_alignment()
			seekoff(1)
			fbyte(0xff)
		end
	end
end

function adts_frame()
	print("adts_frame")
	adts_begin = cur()

	adts_fixed_header()
	adts_variable_header();
	if get("number_of_raw_data_blocks_in_frame") == 0 then
		adts_error_check()


		--raw_data_block()
		rbyte("payload", get("aac_frame_lenght")-7)
		if cur() ~= adts_begin+get("aac_frame_lenght") then
			print("######size error", begin+size, cur())
			seek(adts_begin+get("aac_frame_lenght"))
		else
			print(" - frame size ok")
		end



	else
		adts_header_error_check()
		for i = 0, get("number_of_raw_data_blocks_in_frame") -1 do
			raw_data_block();
			adts_raw_data_block_error_check();
		end
	end
end

function adts_fixed_header(size)
	rbit("sync", 12)
	rbit("id", 1)
	rbit("layer", 2)
	rbit("protection_bit", 1)
	rbit("profile", 2)
	rbit("sampling_freq", 4)
	rbit("private_Bit", 1)
	rbit("channel", 3)
	rbit("original_cpy", 1)
	rbit("home", 1)
end

function adts_variable_header()
	rbit("copyright_identification_bit", 1)
	rbit("copyright_identification_start", 1)
	rbit("aac_frame_lenght", 13)
	rbit("adts_buffer_fullness", 11)
	rbit("number_of_raw_data_blocks_in_frame", 2)
end

function adts_error_check()
	if get("protection_bit") == 0 then
		rbit("crc_check", 16) -- bits rpchof
	end
end

function raw_data_stream()
	while data_available() do
		raw_data_block();
	end
end

function raw_data_block()
	local id
	while true do
		id = rbit("id_syn_ele", 3)
		if id == ID_SCE then
			break
		elseif id == ID_SCE then
			--single_channel_element()
		elseif id == ID_CPE then
			--channel_pair_element()
		elseif id == ID_CCE then
			-- coupling_channel_element()
		elseif id == ID_LFE then
			-- lfe_channel_element()
		elseif id == ID_DSE then
			-- data_stream_element()
		elseif id == ID_PCE then
			-- program_config_element()
		elseif id == ID_FIL then
			-- fill_element()
		else
			print("error")
			break
		end


		-- とりあえず
		break
	end

	byte_alignment()
end

function single_channel_element()
	rbit("element_instance_tag", 4) -- uimsbf
	individual_channel_stream(0)
end

function channel_pair_element()
	rbit("element_instance_tag", 4) -- uimsbf
	rbit("common_window", 1) -- uimsbf
	if get("common_window") then
		ics_info()
		rbit("ms_mask_present", 2) -- uimsbf
		if get("ms_mask_present") == 1 then
			for g = 0, num_window_groups - 1 do
				for sfb = 0, max_sfb - 1 do
					rbit("ms_used[g][sfb]", 1) -- uimsbf
				end
			end
		end
	end

	individual_channel_stream(common_window);
	individual_channel_stream(common_window);
end

function ics_info()
	rbit("ics_reserved_bit", 1) -- bslbf
	rbit("window_sequence", 2) -- uimsbf
	rbit("window_shape", 1) -- uimsbf
	if get("window_sequence") == EIGHT_SHORT_SEQUENCE() then
		rbit("max_sfb", 4) -- uimsbf
		rbit("scale_factor_grouping", 7) -- uimsbf
	else
		rbit("max_sfb", 6) -- uimsbf
		rbit("predictor_data_present", 1) -- uimsbf
		if get("predictor_data_present") then
			rbit("predictor_reset", 1) -- uimsbf
			if get("predictor_reset") then
				rbit("predictor_reset_group_number", 5) -- uimsbf
			end

			for sfb = 0, math.min(get("max_sfb"), PRED_SFB_MAX()) -1 do
				rbit("prediction_used[sfb]", 1) -- uimsbf
			end
		end
	end
end

-- 未
function EIGHT_SHORT_SEQUENCE()
	return 2
end

-- 未
function PRED_SFB_MAX()
	return 40
end

function individual_channel_stream(common_window)
print("individual_channel_stream")
	-- global_gain; 8 uimsbf
	-- if (!common_window)
	-- ics_info();
	-- section_data();
	-- scale_factor_data();
	-- pulse_data_present; 1 uismbf
	-- if (pulse_data_present) {
	-- pulse_data();
	-- }
	-- tns_data_present; 1 uimsbf
	-- if (tns_data_present) {
	-- tns_data();
	-- }
	-- gain_control_data_present; 1 uimsbf
	-- if (gain_control_data_present) {
	-- gain_control_data();
	-- }
	-- spectral_data();
	-- }
end

