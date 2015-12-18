-- PES‰ðÍ
-- VideoPES‚Í‹KŠiãPES_packet_length=0‚ª‹–‰Â‚³‚ê‚Ä‚¢‚é‚Ì‚Å“Á•Êˆµ‚¢‚·‚é

-- PES‚ð“Ç‚Ýž‚Þ‚æ‚¤
dofile(__streamdef_dir__.."pes.lua")
		
local packet_start_code_prefix = 0x000001
local pack_start_code          = 0x000001ba
local system_header_start_code = 0x000001BB
local MPEG_program_end_code    = 0x000001B9
local last_stream_id = 0

function pack()
	local start_code
	nest_call("pack_header", pack_header)

	while lbyte(3) == packet_start_code_prefix do
		nest_call("PES", pes, 0xffff, nil, __out_dir__.."ps_payload(sid="..hexstr(last_stream_id)..").es")

		-- ‹KŠi‚É‚Í‘‚¢‚Ä‚¢‚È‚¢AŽŸ‚ÌƒpƒbƒN
		start_code = lbyte(4)
		if start_code == pack_start_code
		or start_code == MPEG_program_end_code then
			break
		end
	end
end

function pack_header()
	rbit("pack_start_code", 24) -- bslbf
	local last_stream_id = rbit("stream_id", 8) -- bslbf
	rbit("'01'", 2) -- bslbf
	rbit("system_clock_reference_base [32..30]", 3) -- bslbf
	rbit("marker_bit", 1) -- bslbf
	rbit("system_clock_reference_base [29..15]", 15) -- bslbf
	rbit("marker_bit", 1) -- bslbf
	rbit("system_clock_reference_base [14..0]", 15) -- bslbf
	rbit("marker_bit", 1) -- bslbf

	local SCR = get("system_clock_reference_base [32..30]")*0x40000000
		+ get("system_clock_reference_base [29..15]")*0x8000
		+ get("system_clock_reference_base [14..0]")

	set("SCR[90kHz](sid="..hexstr(last_stream_id)..")", SCR)
	set("SCR[ms](sid="..decstr(last_stream_id)..")", SCR/90000)

	rbit("system_clock_reference_extension", 9) -- uimsbf
	rbit("marker_bit", 1) -- bslbf
	rbit("program_mux_rate", 22) -- uimsbf
	rbit("marker_bit", 1) -- bslbf
	rbit("marker_bit", 1) -- bslbf
	rbit("reserved", 5) -- bslbf
	rbit("pack_stuffing_length", 3) -- uimsbf
	for i = 0, get("pack_stuffing_length")-1 do
		rbit("stuffing_byte", 8) -- bslbf
	end
	
	if lbyte(4) == system_header_start_code then
		nest_call("system_header", system_header)
	end
end

function system_header()
	rbit("system_header_start_code", 32) -- bslbf
	rbit("header_length", 16) -- uimsbf
	rbit("marker_bit", 1) -- bslbf
	rbit("rate_bound", 22) -- uimsbf
	rbit("marker_bit", 1) -- bslbf
	rbit("audio_bound", 6) -- uimsbf
	rbit("fixed_flag", 1) -- bslbf
	rbit("CSPS_flag", 1) -- bslbf
	rbit("system_audio_lock_flag", 1) -- bslbf
	rbit("system_video_lock_flag", 1) -- bslbf
	rbit("marker_bit", 1) -- bslbf
	rbit("video_bound", 5) -- uimsbf
	rbit("packet_rate_restriction_flag", 1) -- bslbf
	rbit("reserved_bits", 7) -- bslbf
	while lbit(1) == 1 do
		rbit("stream_id", 8) -- uimsbf
		rbit("'11'", 2) -- bslbf
		rbit("P-STD_buffer_bound_scale", 1) -- bslbf
		rbit("P-STD_buffer_size_bound", 13) -- uimsbf
	end
end

function MPEG2_program_stream(size)
	-- enable_print(true)
	while lbyte(4) == pack_start_code do
		check_progress(false)
		nest_call("pack", pack)
		
		if cur() > size then
			print("analyze more? [y/n (default:n)]")
			if io.read() == "y" then
				size = get_size()
			else
				break
			end
		end
	end
	rbyte("MPEG_program_end_code", 4)
end

-- open(__stream_path__)
-- enable_print(true)
nest_call("MPEG2_program_stream", MPEG2_program_stream, 3*1024*1024)

