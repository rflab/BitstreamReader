function check_stream(s)
	local begin_byte, begin_bit = s:cur()
	local ret = nil
	s:enable_print(true)
	
	repeat -- for break
		
		print("====================================================================================================================")
		--ascii_art("stream?")
		print("check stream...")
		print("")
		
		--
		if s:get_size() < 1024 then
			print("file");
			break;
		end
		
		-- wav
		s:seek(0)
		if s:cstr("RIFF", 4, "RIFF") then
			ret = ".wav"
			break
		end

		-- bmp
		s:seek(0)
		if s:cstr("bfType", 2, "BM") then
			ret = ".bmp"
			break
		end
		
		-- jpg
		s:seek(0)
		if s:cbyte("SOI", 2, 0xffd8) then
			ret = ".jpg"
			break
		end

		-- ts, tts, m2ts, mpg
		s:seek(0)
		if s:fbyte(0x47, true, 192) ~= 192 then
			s:seekoff(188)
			if s:lbyte(1) == 0x47 then 
				ret = ".ts"
				break
			elseif s:seekoff(4) and s:lbyte(1) == 0x47 then
				ret = ".ts"
				break
			end
		end
		
		-- pes
		s:seek(0)
		if __stream_ext__ == ".pes" then
			ret = ".pes"
			break
		end
		
		-- h265
		s:seek(0)
		if s:fstr("00 00 01", true, 1024) ~= 1024 then
			if s:cbyte("start_code_prefix_one_3bytes", 3, 0x000001) then
				if s:cbit("forbidden_zero_bit",    1, 0) then
					ret = ".h265"
					break
				end
			end
		end
		
		-- h264
		s:seek(0)
		if false then
			ret = ".h264"
			break
		end

		-- AAC
		s:seek(0)
		if s:cbit("syncword", 12, 0xfff) then
			s:rbit("id", 1)
			if s:cbit("layer", 2, 0) then
				if s:get("id") == 0 then
					print("MPEG-4 AAC")
				elseif s:get("id") == 1 then
					print("MPEG-2 AAC")
				end
				ret = ".aac"
				break
			end
		end
		
		-- mp3
		s:seek(0)
		if s:cbit("syncword", 12, 0xfff) then
			s:rbit("id", 1)
			if s:cbit("layer", 2, 1) then
				ret = ".mp3"
				break
			end
		end
		

		-- mp4
		s:seek(0)
		if s:fstr("ftyp", true, 8) ~= 8 then
			ret = ".mp4"
			break
		end

		-- dat
		if __stream_ext__ == ".dat" then
			ret = ".dat"
			break
		end
		
		-- test
		if __stream_ext__ == ".test" then
			ret = ".test"
			break
		end
		
		-- txt
		if __stream_ext__ == ".txt" then
			ret = ".txt"
			break
		end
		
		-- zip
		s:seek(0)
		if s:cbyte("signature", 4, 0x504b0304) then
			ret = ".zip"
			break
		end
		
		-- unknown
		ret = ".unknown"

	until true 

	-- print("stream_type = "..ret)
	ascii_art(ret)
	print("====================================================================================================================")

	s:seek(begin_byte, begin_bit)
	s:enable_print(true)
	return ret
end

function ascii_art(stream_type)
	if stream_type == "stream?" then
		print("                                          #####  ")
		print(" ####  ##### #####  ######   ##   #    # #     # ")
		print("#        #   #    # #       #  #  ##  ##       # ")
		print(" ####    #   #    # #####  #    # # ## #    ###  ")
		print("     #   #   #####  #      ###### #    #    #    ")
		print("#    #   #   #   #  #      #    # #    #         ")
		print(" ####    #   #    # ###### #    # #    #    #    ")
	elseif stream_type == ".wav" then
		print("")
		print("#    #   ##   #    # ")
		print("#    #  #  #  #    # ")
		print("#    # #    # #    # ")
		print("# ## # ###### #    # ")
		print("##  ## #    #  #  #  ")
		print("#    # #    #   ##   ")
	elseif stream_type == ".bmp" then
		print("")
		print("#####  # ##### #    #   ##   #####  ")
		print("#    # #   #   ##  ##  #  #  #    # ")
		print("#####  #   #   # ## # #    # #    # ")
		print("#    # #   #   #    # ###### #####  ")
		print("#    # #   #   #    # #    # #      ")
		print("#####  #   #   #    # #    # #      ")
	elseif stream_type == ".jpg" then
		print("")
		print("     # #####  ######  ####  ")
		print("     # #    # #      #    # ")
		print("     # #    # #####  #      ")
		print("     # #####  #      #  ### ")
		print("#    # #      #      #    # ")
		print(" ####  #      ######  ####  ")
	elseif stream_type == ".ts" then
		print("                                   #####                  ")
		print("#    # #####  ######  ####        #     #    #####  ####  ")
		print("##  ## #    # #      #    #             #      #   #      ")
		print("# ## # #    # #####  #      #####  #####       #    ####  ")
		print("#    # #####  #      #  ###       #            #        # ")
		print("#    # #      #      #    #       #            #   #    # ")
		print("#    # #      ######  ####        #######      #    ####  ")
	elseif stream_type == ".pes" then
		print("")
		print("#####  ######  ####  ")
		print("#    # #      #      ")
		print("#    # #####   ####  ")
		print("#####  #           # ")
		print("#      #      #    # ")
		print("#      ######  ####  ")
		print("")
	elseif stream_type == ".h264" then
		print("        #####   #####  #       ")
		print("#    # #     # #     # #    #  ")
		print("#    #       # #       #    #  ")
		print("######  #####  ######  #    #  ")
		print("#    # #       #     # ####### ")
		print("#    # #       #     #      #  ")
		print("#    # #######  #####       #  ")
	elseif stream_type == ".h265" then
		print("        #####   #####  ####### ")
		print("#    # #     # #     # #       ")
		print("#    #       # #       #       ")
		print("######  #####  ######  ######  ")
		print("#    # #       #     #       # ")
		print("#    # #       #     # #     # ")
		print("#    # #######  #####   #####  ")
	elseif stream_type == ".mp4" then
		print("              #       ")
		print("#    # #####  #    #  ")
		print("##  ## #    # #    #  ")
		print("# ## # #    # #    #  ")
		print("#    # #####  ####### ")
		print("#    # #           #  ")
		print("#    # #           #  ")
	elseif stream_type == ".dat" then	
		print("")
		print("#####    ##   ##### ")
		print("#    #  #  #    #   ")
		print("#    # #    #   #   ")
		print("#    # ######   #   ")
		print("#    # #    #   #   ")
		print("#####  #    #   #   ")
	elseif stream_type == ".test" then
		print("")
		print("##### ######  ####  ##### ")
		print("  #   #      #        #   ")
		print("  #   #####   ####    #   ")
		print("  #   #           #   #   ")
		print("  #   #      #    #   #   ")
		print("  #   ######  ####    #   ")
	elseif stream_type == ".txt" then
		print("")
		print("##### ###### #    # ##### ")
		print("  #   #       #  #    #   ")
		print("  #   #####    ##     #   ")
		print("  #   #        ##     #   ")
		print("  #   #       #  #    #   ")
		print("  #   ###### #    #   #   ")
	elseif stream_type == ".zip" then
		print("")
		print("###### # #####  ")
		print("    #  # #    # ")
		print("   #   # #    # ")
		print("  #    # #####  ")
		print(" #     # #      ")
		print("###### # #      ")
	elseif stream_type == ".unknown" then
		print("")
		print("#    # #    # #    # #    #  ####  #    # #    # ")
		print("#    # ##   # #   #  ##   # #    # #    # ##   # ")
		print("#    # # #  # ####   # #  # #    # #    # # #  # ")
		print("#    # #  # # #  #   #  # # #    # # ## # #  # # ")
		print("#    # #   ## #   #  #   ## #    # ##  ## #   ## ")
		print(" ####  #    # #    # #    #  ####  #    # #    # ")
	end
end


--  if c = " " then
-- elseif c = "!" then
-- elseif c = "\"" then
-- elseif c = "#" then
-- elseif c = "$" then
-- elseif c = "%" then
-- elseif c = "&" then
-- elseif c = "'" then
-- elseif c = "(" then
-- elseif c = ")" then
-- elseif c = "*" then
-- elseif c = "+" then
-- elseif c = "," then
-- elseif c = "-" then
-- elseif c = "." then
-- elseif c = "/" then
-- elseif c = "0" then
-- elseif c = "1" then
-- elseif c = "2" then
-- elseif c = "3" then
-- elseif c = "4" then
-- elseif c = "5" then
-- elseif c = "6" then
-- elseif c = "7" then
-- elseif c = "8" then
-- elseif c = "9" then
-- elseif c = ":" then
-- elseif c = ";" then
-- elseif c = "<" then
-- elseif c = "=" then
-- elseif c = ">" then
-- elseif c = "?" then
-- elseif c = "@" then
-- elseif c = "A" then
-- elseif c = "B" then
-- elseif c = "C" then
-- elseif c = "D" then
-- elseif c = "E" then
-- elseif c = "F" then
-- elseif c = "G" then
-- elseif c = "H" then
-- elseif c = "I" then
-- elseif c = "J" then
-- elseif c = "K" then
-- elseif c = "L" then
-- elseif c = "M" then
-- elseif c = "N" then
-- elseif c = "O" then
-- elseif c = "P" then
-- elseif c = "Q" then
-- elseif c = "R" then
-- elseif c = "S" then
-- elseif c = "T" then
-- elseif c = "U" then
-- elseif c = "V" then
-- elseif c = "W" then
-- elseif c = "X" then
-- elseif c = "Y" then
-- elseif c = "Z" then
-- elseif c = "[" then
-- elseif c = "\\" then
-- elseif c = "]" then
-- elseif c = "^" then
-- elseif c = "_" then
-- elseif c = "`" then
-- elseif c = "a" then
-- elseif c = "b" then
-- elseif c = "c" then
-- elseif c = "d" then
-- elseif c = "e" then
-- elseif c = "f" then
-- elseif c = "g" then
-- elseif c = "h" then
-- elseif c = "i" then
-- elseif c = "j" then
-- elseif c = "k" then
-- elseif c = "l" then
-- elseif c = "m" then
-- elseif c = "n" then
-- elseif c = "o" then
-- elseif c = "p" then
-- elseif c = "q" then
-- elseif c = "r" then
-- elseif c = "s" then
-- elseif c = "t" then
-- elseif c = "u" then
-- elseif c = "v" then
-- elseif c = "w" then
-- elseif c = "x" then
-- elseif c = "y" then
-- elseif c = "z" then
-- elseif c = "{" then
-- elseif c = "|" then
-- elseif c = "}" then
-- elseif c = "~" then
-- elseif c = "｡" then
-- elseif c = "｢" then
-- elseif c = "｣" then
-- elseif c = "､" then
-- elseif c = "･" then
-- end

 