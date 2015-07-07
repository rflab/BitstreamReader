local function analyse_stream_type(s)
	local prev_stream = swap(s)
	local begin_byte, begin_bit = cur()
	local ret = nil
	local ascii = nil
	
	repeat -- for break
		
		print("====================================================================================================================")
		--ascii_art("stream?")
		print("check stream...")
		print("")		

		-- test	
		if __stream_ext__ == ".test" then
			ret = ".test"
			ascii = "Test"
			break;
		end
		
		-- txt
		if __stream_ext__ == ".txt" then
			ret = ".txt"
			ascii = "Text"
			break
		end
		
		--
		if get_size() < 128 then
			print("short file.");
			break;
		end
		
		-- RIFF‚Ì‚Ù‚¤‚ª³Šm
		-- -- wav
		-- seek(0)
		-- if cstr("ckID", 4, "RIFF") then
		-- 	seekoff(4) 
		-- 	if cstr("ckData", 4, "WAVE") then 
		-- 		ret = ".wav"
		-- 		ascii = "Wave"
		-- 		break
		-- 	end
		-- end
		
		-- riff other than wave and avi
		seek(0)
		if cstr("RIFF", 4, "RIFF") then
			seekoff(4) 
			local id = lstr(4)
			ret = ".iff"
			ascii = "Riff/"..id
			break
		end
		
		-- riff other than wave and avi
		seek(0)
		if cstr("FORM", 4, "FORM") then
			seekoff(4) 
			local id = lstr(4)
			ret = ".iff"
			ascii = "Iff/"..id
			break
		end

		-- bmp
		seek(0)
		if cstr("bfType", 2, "BM") then
			ret = ".bmp"
			ascii = "Bitmap"
			break
		end
		
		-- jpg
		seek(0)
		if cbyte("SOI", 2, 0xffd8) then
			ret = ".jpg"
			ascii = "Jpeg"
			break
		end

		-- ts, tts, m2ts, mpg
		seek(0)
		if fbyte(0x47, true, 192) ~= 192 then
			seekoff(188)
			if lbyte(1) == 0x47
			or seekoff(4) and lbyte(1) == 0x47 then
				ret = ".ts"
				ascii = "MPEG-2 TS"
				break
			end
		end
		
		-- pes
		seek(0)
		if __stream_ext__ == ".pes" then
			ret = ".pes"
			ascii = "PES"
			break
		end

		-- AAC
		seek(0)
		if cbit("syncword", 12, 0xfff) then
			rbit("id", 1)
			if cbit("layer", 2, 0) then
				if get("id") == 0 then
					print("MPEG-4 AAC")
				elseif get("id") == 1 then
					print("MPEG-2 AAC")
				end
				ret = ".aac"
				ascii = "AAC"
				break
			end
		end
		
		-- mp3
		seek(0)
		if cbit("syncword", 12, 0xfff) then
			rbit("id", 1)
			if cbit("layer", 2, 1) then
				ret = ".mp3"
				ascii = "MP3"
				break
			end
		end
		

		-- mp4
		seek(0)
		if fstr("ftyp", true, 8) ~= 8 then
			ret = ".mp4"
			ascii = "MPEG-4 Part 14"
			break
		end

		-- dat
		if __stream_ext__ == ".dat" then
			ret = ".dat"
			ascii = "Data"
			break
		end
		
		
		-- zip
		seek(0)
		if cbyte("signature", 4, 0x504b0304) then
			ret = ".zip"
			ascii = "Zip"
			break
		end
		
		
		-- h265
		seek(0)
		if lbyte(3) == 1 or lbyte(4) == 1 then
			fstr("00 00 01", true, 10)
			if cbyte("start_code_prefix_one_3bytes", 3, 0x000001) then
				if cbit("forbidden_zero_bit",    1, 0) then
					ret = ".h265"
					ascii = "H.265/HEVC"
					break
				end
			end
		end
		
		-- h264
		seek(0)
		if false then
			ret = ".h264"
			ascii = "H.264/MPEG-4 AVC"
			break
		end
		
		-- unknown
		__stream_type__ = ".unknown"
		ascii = "Unknown"

	until true 

	__stream_type__ = ret

	print()
	print_ascii(ascii)
	print("====================================================================================================================")

	seek(begin_byte, begin_bit)
	swap(prev_stream)
	return ret
end

function dispatch_stream(stream)
	local st = analyse_stream_type(stream)

	if st == ".test" then
		dofile(__exec_dir__.."script/streamdef/test.lua")

	elseif st == ".wav" then
		dofile(__exec_dir__.."script/streamdef/wav.lua")

	elseif st == ".iff" then
		dofile(__exec_dir__.."script/streamdef/iff.lua")
		
	elseif st == ".bmp" then
		dofile(__exec_dir__.."script/streamdef/bmp.lua")
		
	elseif st == ".jpg"
	or     st == ".JPG" then
		dofile(__exec_dir__.."script/streamdef/jpg.lua")
		
	elseif st == ".ts"
	or     st == ".tts"
	or     st == ".m2ts"
	or     st == ".MPG"
	or     st == ".mpg" then
		dofile(__exec_dir__.."script/streamdef/ts.lua")
		
	elseif st == ".pes" then
		dofile(__exec_dir__.."script/streamdef/pes.lua")

	elseif st == ".h264" then
		dofile(__exec_dir__.."script/streamdef/h264.lua")

	elseif st == ".h265" then
		dofile(__exec_dir__.."script/streamdef/h265.lua")

	elseif st == ".mp4" then
		dofile(__exec_dir__.."script/streamdef/mp4.lua")

	elseif st == ".dat" then
		dofile(__exec_dir__.."script/streamdef/dat.lua")
		
	elseif string.match(argv[1], "^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
		dofile(__exec_dir__.."script/streamdef/string.lua")

	elseif st == ".txt" then
		dump(256)
		
	else
		print("not found extension")
	end
end

-- " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
local ascii_array = 
{{"   ", "### ", "### ### ", "  # #   ", " #####  ", "###   # ", "  ##    ", "### ", "  ## ", "##   ", "        ", "      ", "    ", "      ", "    ", "      # ", "  ###    ", "  #   ", " #####  ", " #####  ", "#       ", "####### ", " #####  ", "####### ", " #####  ", " #####  ", " #  ", "### ", "   # ", "      ", "#    ", " #####  ", " #####  ", "   #    ", "######  ", " #####  ", "######  ", "####### ", "####### ", " #####  ", "#     # ", "### ", "      # ", "#    # ", "#       ", "#     # ", "#     # ", "####### ", "######  ", " #####  ", "######  ", " #####  ", "####### ", "#     # ", "#     # ", "#     # ", "#     # ", "#     # ", "####### ", "##### ", "#       ", "##### ", "  #   ", "        ", "### ", "       ", "       ", "       ", "       ", "       ", "       ", "       ", "       ", "  ", "       ", "       ", "       ", "       ", "       ", "       ", "       ", "       ", "       ", "       ", "      ", "       ", "       ", "       ", "       ", "      ", "       ", "  ### ", "# ", "###   ", " ##     "},
 {"   ", "### ", "### ### ", "  # #   ", "#  #  # ", "# #  #  ", " #  #   ", "### ", " #   ", "  #  ", " #   #  ", "  #   ", "    ", "      ", "    ", "     #  ", " #   #   ", " ##   ", "#     # ", "#     # ", "#    #  ", "#       ", "#     # ", "#    #  ", "#     # ", "#     # ", "### ", "### ", "  #  ", "      ", " #   ", "#     # ", "#     # ", "  # #   ", "#     # ", "#     # ", "#     # ", "#       ", "#       ", "#     # ", "#     # ", " #  ", "      # ", "#   #  ", "#       ", "##   ## ", "##    # ", "#     # ", "#     # ", "#     # ", "#     # ", "#     # ", "   #    ", "#     # ", "#     # ", "#  #  # ", " #   #  ", " #   #  ", "     #  ", "#     ", " #      ", "    # ", " # #  ", "        ", "### ", "  ##   ", "#####  ", " ####  ", "#####  ", "###### ", "###### ", " ####  ", "#    # ", "# ", "     # ", "#    # ", "#      ", "#    # ", "#    # ", " ####  ", "#####  ", " ####  ", "#####  ", " ####  ", "##### ", "#    # ", "#    # ", "#    # ", "#    # ", "#   # ", "###### ", " #    ", "# ", "   #  ", "#  #  # "},
 {"   ", "### ", " #   #  ", "####### ", "#  #    ", "### #   ", "  ##    ", " #  ", "#    ", "   # ", "  # #   ", "  #   ", "    ", "      ", "    ", "    #   ", "#     #  ", "# #   ", "      # ", "      # ", "#    #  ", "#       ", "#       ", "    #   ", "#     # ", "#     # ", " #  ", "    ", " #   ", "##### ", "  #  ", "      # ", "# ### # ", " #   #  ", "#     # ", "#       ", "#     # ", "#       ", "#       ", "#       ", "#     # ", " #  ", "      # ", "#  #   ", "#       ", "# # # # ", "# #   # ", "#     # ", "#     # ", "#     # ", "#     # ", "#       ", "   #    ", "#     # ", "#     # ", "#  #  # ", "  # #   ", "  # #   ", "    #   ", "#     ", "  #     ", "    # ", "#   # ", "        ", " #  ", " #  #  ", "#    # ", "#    # ", "#    # ", "#      ", "#      ", "#    # ", "#    # ", "# ", "     # ", "#   #  ", "#      ", "##  ## ", "##   # ", "#    # ", "#    # ", "#    # ", "#    # ", "#      ", "  #   ", "#    # ", "#    # ", "#    # ", " #  #  ", " # #  ", "    #  ", " #    ", "# ", "   #  ", "    ##  "},
 {"   ", " #  ", "        ", "  # #   ", " #####  ", "   #    ", " ###    ", "#   ", "#    ", "   # ", "####### ", "##### ", "### ", "##### ", "    ", "   #    ", "#     #  ", "  #   ", " #####  ", " #####  ", "#    #  ", "######  ", "######  ", "   #    ", " #####  ", " ###### ", "    ", "### ", "#    ", "      ", "   # ", "   ###  ", "# ### # ", "#     # ", "######  ", "#       ", "#     # ", "#####   ", "#####   ", "#  #### ", "####### ", " #  ", "      # ", "###    ", "#       ", "#  #  # ", "#  #  # ", "#     # ", "######  ", "#     # ", "######  ", " #####  ", "   #    ", "#     # ", "#     # ", "#  #  # ", "   #    ", "   #    ", "   #    ", "#     ", "   #    ", "    # ", "      ", "        ", "  # ", "#    # ", "#####  ", "#      ", "#    # ", "#####  ", "#####  ", "#      ", "###### ", "# ", "     # ", "####   ", "#      ", "# ## # ", "# #  # ", "#    # ", "#    # ", "#    # ", "#    # ", " ####  ", "  #   ", "#    # ", "#    # ", "#    # ", "  ##   ", "  #   ", "   #   ", "##    ", "  ", "   ## ", "        "},
 {"   ", "    ", "        ", "####### ", "   #  # ", "  # ### ", "#   # # ", "    ", "#    ", "   # ", "  # #   ", "  #   ", "### ", "      ", "    ", "  #     ", "#     #  ", "  #   ", "#       ", "      # ", "####### ", "      # ", "#     # ", "  #     ", "#     # ", "      # ", " #  ", "### ", " #   ", "##### ", "  #  ", "   #    ", "# ####  ", "####### ", "#     # ", "#       ", "#     # ", "#       ", "#       ", "#     # ", "#     # ", " #  ", "#     # ", "#  #   ", "#       ", "#     # ", "#   # # ", "#     # ", "#       ", "#   # # ", "#   #   ", "      # ", "   #    ", "#     # ", " #   #  ", "#  #  # ", "  # #   ", "   #    ", "  #     ", "#     ", "    #   ", "    # ", "      ", "        ", "    ", "###### ", "#    # ", "#      ", "#    # ", "#      ", "#      ", "#  ### ", "#    # ", "# ", "     # ", "#  #   ", "#      ", "#    # ", "#  # # ", "#    # ", "#####  ", "#  # # ", "#####  ", "     # ", "  #   ", "#    # ", "#    # ", "# ## # ", "  ##   ", "  #   ", "  #    ", " #    ", "# ", "   #  ", "        "},
 {"   ", "### ", "        ", "  # #   ", "#  #  # ", " #  # # ", "#    #  ", "    ", " #   ", "  #  ", " #   #  ", "  #   ", " #  ", "      ", "### ", " #      ", " #   #   ", "  #   ", "#       ", "#     # ", "     #  ", "#     # ", "#     # ", "  #     ", "#     # ", "#     # ", "### ", " #  ", "  #  ", "      ", " #   ", "        ", "#       ", "#     # ", "#     # ", "#     # ", "#     # ", "#       ", "#       ", "#     # ", "#     # ", " #  ", "#     # ", "#   #  ", "#       ", "#     # ", "#    ## ", "#     # ", "#       ", "#    #  ", "#    #  ", "#     # ", "   #    ", "#     # ", "  # #   ", "#  #  # ", " #   #  ", "   #    ", " #      ", "#     ", "     #  ", "    # ", "      ", "        ", "    ", "#    # ", "#    # ", "#    # ", "#    # ", "#      ", "#      ", "#    # ", "#    # ", "# ", "#    # ", "#   #  ", "#      ", "#    # ", "#   ## ", "#    # ", "#      ", "#   #  ", "#   #  ", "#    # ", "  #   ", "#    # ", " #  #  ", "##  ## ", " #  #  ", "  #   ", " #     ", " #    ", "# ", "   #  ", "        "},
 {"   ", "### ", "        ", "  # #   ", " #####  ", "#   ### ", " ###  # ", "    ", "  ## ", "##   ", "        ", "      ", "#   ", "      ", "### ", "#       ", "  ###    ", "##### ", "####### ", " #####  ", "     #  ", " #####  ", " #####  ", "  #     ", " #####  ", " #####  ", " #  ", "#   ", "   # ", "      ", "#    ", "   #    ", " #####  ", "#     # ", "######  ", " #####  ", "######  ", "####### ", "#       ", " #####  ", "#     # ", "### ", " #####  ", "#    # ", "####### ", "#     # ", "#     # ", "####### ", "#       ", " #### # ", "#     # ", " #####  ", "   #    ", " #####  ", "   #    ", " ## ##  ", "#     # ", "   #    ", "####### ", "##### ", "      # ", "##### ", "      ", "####### ", "    ", "#    # ", "#####  ", " ####  ", "#####  ", "###### ", "#      ", " ####  ", "#    # ", "# ", " ####  ", "#    # ", "###### ", "#    # ", "#    # ", " ####  ", "#      ", " ### # ", "#    # ", " ####  ", "  #   ", " ####  ", "  ##   ", "#    # ", "#    # ", "  #   ", "###### ", "  ### ", "# ", "###   ", "        "}}

function print_ascii(str)
	str = str or ""
	for i=1, #ascii_array do
		for j=1, #str do
			io.write(ascii_array[i][str:byte(j)-0x20+1])
		end
		io.write("\n")
	end
end
