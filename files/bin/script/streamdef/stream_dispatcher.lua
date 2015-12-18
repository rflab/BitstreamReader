local function analyse_stream_type(s)
	local prev_stream = swap(s)
	local begin_byte, begin_bit = cur()
	local ret = nil
	local ascii = nil
	
	repeat -- for break
		
		print("====================================================================================================================")

		-- dat
		if __stream_ext__ == ".dat" then
			print("please input extention. (ex. \"wav\")")
			ret = "."..io.read()
			ascii = ret
			break
		end

		-- test	
		if __stream_ext__ == ".test" then
			ret = ".test"
			ascii = "Test"
			break;
		end
		
		if get_size() < 16 then
			print("short file.");
			ret = ".dat"
			ascii = "Unknown"
			break;
		end
		
		-- hextext
		if gstr(3):find("^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
			if gstr(3):find("^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
				if gstr(3):find("^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
					if gstr(3):find("^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
						ret = ".hextext"
						ascii = "Hex Convert"
						break
					end
				end
			end
		end
		
		-- txt
		if __stream_ext__ == ".txt" then
			seek(0)
			if lbyte(3) == 0xefbbbf then
				ascii = "UTF-8 BOM"
			elseif lbyte(2) == 0xfeff then
				ascii = "UTF-16 BOM(BE)"
			elseif lbyte(2) == 0xfffe then
				ascii = "UTF-16 BOM(LE)"
			else
				ascii = "Text"
			end
			ret = ".txt"
			break
		end
		

		
		-- RIFFのほうが正確
		-- -- wav
		-- seek(0)
		-- if gstr("ckID", 4, "RIFF") then
		-- 	seekoff(4) 
		-- 	if cstr("ckData", 4, "WAVE") then 
		-- 		ret = ".wav"
		-- 		ascii = "Wave"
		-- 		break
		-- 	end
		-- end
		
		-- riff other than wave and avi
		seek(0)
		if gstr(4) == "RIFF" then
			seekoff(4) 
			local id = lstr(4)
			ret = ".iff"
			ascii = "Riff/"..id
			break
		end
		
		-- riff other than wave and avi
		seek(0)
		if gstr(4) == "FORM" then
			seekoff(4) 
			local id = lstr(4)
			ret = ".iff"
			ascii = "Iff/"..id
			break
		end
		
		-- bmp
		seek(0)
		if gstr(2) == "BM" then
			ret = ".bmp"
			ascii = "Bitmap"
			break
		end
		
		-- jpg
		seek(0)
		if gbyte(2) == 0xffd8 then
			ret = ".jpg"
			ascii = "Jpeg"
			break
		end

		-- ts, tts, m2ts, mpg
		seek(0)
		if get_size() > 384 then
			if fbyte(0x47, 192, true) ~= 192 then
				seekoff(188)
				if lbyte(1) == 0x47 then
					ret = ".ts"
					ascii = "MPEG-2 TS"
					break
				else
					seekoff(4)
					if lbyte(1) == 0x47 then
						ret = ".tts"
						ascii = "MPEG-2 TS(TTS)"
						break
					end
				end
			end
		end
		
		-- mp3(ID3v2)
		seek(0)
		if gbyte(3) == 0x494433 then
			ret = ".mp3"
			ascii = "mp3 ID3v2"
			break
		end
		
		-- mp3(ID3v1)
		seek(get_size() - 128)
		if gbyte(3) == 0x544147 then
			ret = ".mp3"
			ascii = "mp3 ID3v1"
			break
		end

		-- mpeg audio		
		seek(0)
		if gbit(11) == 0x7ff then
			local id = gbit(1)
			local layer = gbit(2)
			if layer == 0 then
				if id == 0 then
					ascii = "MPEG-4 AAC"
				elseif id == 1 then
					ascii = "MPEG-2 AAC"
				end
				ret = ".aac"
				break
			elseif layer == 1 then
				ascii = "MP3"
				ret = ".mp3"
				break
			else				
				ascii = "MPEG Auido Layer"..math.ceil(layer)
				ret = ".mp2"
				break
			end
		end
		
		-- mp4
		seek(0)
		if fstr("ftyp", 5, true) == 4 then
			ret = ".mp4"
			ascii = "MPEG-4 Part 14"
			break
		end

		-- zip
		seek(0)
		if gbyte(4) == 0x504b0304 then
			ret = ".zip"
			ascii = "Zip"
			break
		end
		
		
		-- ogg
		seek(0)
		if gbyte(4) == 0x4f676753 then
			ret = ".ogg"
			ascii = "Ogg Vorbis"
			break
		end
			
		
		-- wmv
		seek(0)
		if gbyte(2) == 0x3026 then
			ret = ".wmv"
			ascii = "wmv?"
			break
		end
		
		-- flv
		seek(0)
		if gbyte(3) == 0x464c56 then
			ret = ".flv"
			ascii = "Flash Video"
			break
		end
		
		-- ac3
		seek(0)
		if gbyte(2) == 0x0b77 then
			ret = ".ac3"
			ascii = "AC-3/E-AC-3"
			break
		end
		
		--mkv
		seek(8)
		if gstr(8) == "matroska" then
			ret = ".mkv"
			ascii = "MKV (matroska)"
			break
		end
				
		-- PDF
		seek(0)
		if gbyte(4) == 0x25504446 then
			ret = ".pdf"
			ascii = "PDF"
			break
		end
		
		-- exe
		seek(0)
		if gbyte(2) == 0x4d5a then
			ret = ".exe"
			ascii = ".exe"
			break
		end
		
		-- png
		seek(0)
		if gbyte(4) == 0x89504e47 then
			ret = ".png"
			ascii = "PNG"
			break
		end

		-- gif
		seek(0)
		if gbyte(3) == 0x474946 then
			ret = ".gif"
			ascii = "GIF"
			break
		end
		
		-- ショートカット
		seek(0)
		if gbyte(4) == 0x4c000000 then
			ret = ".link"
			ascii = "Link"
			break
		end
		
		------------------ 
		-- 以下、判定が難しい
		------------------ 

		-- h265
		seek(0)
		if lbyte(3) == 1 or lbyte(4) == 1 then
			fstr("00 00 01", 10, true)
			if gbyte(3) == 0x000001 then
				if gbit(1) == 0 then
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
		
		-- ps/pes
		seek(0)
		if lbyte(3) == 1 then
			seek(3)
			if lbyte(1) == 0xba then
				ret = ".ps"
				ascii = "PS"
				break
			elseif lbyte(1) == 0xe0 then
				ret = ".pes"
				ascii = "Video PES"
				break
			elseif lbyte(1) == 0xc0 then
				ret = ".pes"
				ascii = "Audio PES"
				break
			else
				ret = ".pes"
				ascii = "PS"
				break
			end
			--seek(6)
			--if lbit(2) == 1 then
			--	ret = ".pes"
			--	ascii = "PES?"
			--end
		end

		-- 当てずっぽう
		seek(0)
		if string.match(lstr(4), "%a%a%a%a") ~= nil then
			seek(4)
			if get_size() > gbyte(4) then
				ret = ".iff"
				ascii = "Iff?"
				break
			end
		end

		-- unknown
		ret= __stream_ext__
		ascii = "Unknown ["..__stream_ext__.."]"

	until true 

	print()
	print_ascii(ascii)
	-- print(ascii)
	print("====================================================================================================================")

	seek(begin_byte, begin_bit)
	swap(prev_stream)
	return ret
end

function dispatch_stream(stream)
	local st = analyse_stream_type(stream)
	
	-- 前回のエラー情報を読み込む
	load_error_info()
	
	if st == ".test" then
		dofile(__streamdef_dir__.."test.lua")

	elseif st == ".wav" then
		dofile(__streamdef_dir__.."wav.lua")

	elseif st == ".iff" then
		dofile(__streamdef_dir__.."iff.lua")
		
	elseif st == ".bmp" then
		dofile(__streamdef_dir__.."bmp.lua")
		
	elseif st == ".jpg" then
		dofile(__streamdef_dir__.."jpg.lua")
		
	elseif st == ".mp3" then
		dofile(__streamdef_dir__.."mp3.lua")
		
	elseif st == ".ts"
	or     st == ".tts"
	or     st == ".m2ts"
	or     st == ".MPG"
	or     st == ".mpg" then
		dofile(__streamdef_dir__.."ts.lua")
		
	elseif st == ".pes" then
		dofile(__streamdef_dir__.."pes.lua")
		pes_stream(get_size())
		
	elseif st == ".ps" then
		dofile(__streamdef_dir__.."ps.lua")

	elseif st == ".h264" then
		dofile(__streamdef_dir__.."h264.lua")

	elseif st == ".h265" then
		dofile(__streamdef_dir__.."h265.lua")

	elseif st == ".mp4" then
		dofile(__streamdef_dir__.."mp4.lua")

	elseif st == ".dat" then
		dofile(__streamdef_dir__.."dat.lua")
		
	elseif st == ".aac" then
		dofile(__streamdef_dir__.."aac.lua")
		adts_sequence(get_size())
		
	elseif st == ".ac3" then
		dofile(__streamdef_dir__.."ac3.lua")
		ac3_bitstream(get_size())
		
	elseif st == ".flv" then
		dofile(__streamdef_dir__.."flv.lua")
		flv_file(get_size())
		
	elseif st == ".hextext" then
		dofile(__streamdef_dir__.."hextext.lua")

	elseif string.match(argv[1], "^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
		dofile(__streamdef_dir__.."hexarg.lua")

	elseif st == ".txt" then
		dump(256)
		
	else
		print("unsupported file type")
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
