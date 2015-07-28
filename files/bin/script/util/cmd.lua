local history = {}

function touint(val)
	if type(val) ~= "number" then
		print("invalid arg - return 0.")
		return 0
	end
	local ix = math.ceil(val)
	if ix < 0 then
		print("invalid arg - return 0.")
		return 0
	end
	return ix
end

function toindex(val, tbl)
	assert(tbl ~= nil)
	if type(val) ~= "number" then
		print("invalid inxex - return 1")
		return 1 
	end
	local ix = math.ceil(val)
	if ix <= 0
	or ix > #tbl then
		print("invalid inxex - return #tbl")
		return #tbl
	end
	return ix
end

function exec_cmd(c)
	repeat
		if c[1] == "history" then
			print_table(history)
		elseif c[1] == "open" then
			if type(c[2]) == "string" then
				open(__stream_dir__..c[2])
			end
		elseif c[1] == "info" then
			local data = get_data()
			local vs, ts, bys, bis, skipcnt = data.values, data.tables, data.bytes, data.bits, data.skipcnt
			for k, v in pairs(vs) do
				local num  = ts[k] and #(ts[k]) or 0
				local byte = bys[k] and bys[k][#(bis[k])] or 0
				local bit  = bis[k] and bis[k][#(bis[k])] or 0
				local numstr = ""
				if skipcnt[k] ~= nil then
					numstr = tostring(num+1).."/"..skipcnt[k]+num
				else
					numstr = tostring(num)
				end
				printf("  adr=0x%08x(+%d) [%10s]| %-50s %-8s", byte, bit, numstr, k, hexstr(v))
			end
			print_status()
		elseif c[1] == "grep" then
			local data = get_data()
			local vs, ts, bys, bis = data.values, data.tables, data.bytes, data.bits
			local num
			local byte
			local bit
			for i = 2, #c do
				print("["..c[i].."]")
				for k, v in pairs(vs) do
					if string.find(k, c[i]) ~= nil then
						local num = ts[k] and #(ts[k]) or 0
						--printf("  %-50s %-8s [%d]", k, v, num)
						num  = ts[k]  and #(ts[k])  or 0
						byte = bys[k] and bys[k][#(bys[k])] or 0
						bit  = bis[k] and bis[k][#(bis[k])] or 0
						print(k,  bys[k],  bis[k])
						printf("  adr=0x%08x(+%d) [%6d]| %-50s %-8s", byte, bit, num, k, hexstr(v))
					end
				end
			end
		elseif c[1] == "list" then
			local data = get_data()
			local vs, ts, bys, bis, sizs, streams
				 = data.values, data.tables, data.bytes, data.bits, data.sizes, data.streams
			local print_continue = nil
			local function print_values(k)
				local count = 0
				print ("    no.         stream       address         size        value         ")
				print ("    ----------  -----------  --------------  ----------  --------------")
				for i, v in ipairs(ts[k]) do
					count = count + 1
					if count % 1000 == 0 then
						
						print(k.."["..count.."]")
						print("n:next")
						if io.read() ~= "n" then
							break
						end
					end
					printf("    %10s  %11s  0x%08x(+%d)  %10s  %14s",
						i, trimstr(streams[k][i].name, 10), bys[k][i], bis[k][i], sizs[k][i], trimstr(hexstr(v), 14))
				end
			end
			for i = 2, #c do
				print("["..c[i].."]")
				for k, v in pairs(vs) do
					if string.find(k, c[i]) ~= nil then
						local num = ts[k] and #(ts[k]) or 0
						printf("  %s[%d]", k, num)
						local t = ts[k]
						if type(t) == "table" then
							if #t > 1000 then
								if print_continue == nil then
									print("table size is ".. #t..", continue? [y]")
									if io.read() == "y" then
										print_continue = true
										print_values(k)
									else
										print_continue = false
										print("    give up print.")
									end
								elseif print_continue == false then
									print("    give up print.")
								elseif print_continue == true then
									print_values(k)
								end
							else
								print_values(k)
							end
						end
						print("")
					end
				end
			end
		elseif c[1] == "find" then
			
			if type(c[2]) == "string" then
				local find_func = fstr
				local limit = 0x10000
				local address = tonumber(c[3]) or 0
				seek(address)
				while true do
							print("0000")
					if find_func(c[2], true, limit) == false then
						print("not found ["..c[2].."]")
						break;
					else
						print("found ["..c[2].."]")
						dump()
						
						print("n:next, p:prev")
						local c = io.read()
						if c == "n"  then
							if get_size() <= cur() then
								print("[EOS]")
								break;
							end
							seekoff(1)
							find_func = fstr
							limit = 0x10000
						elseif c == "p" then
							if cur() <= 0then
								print("[pos=0]")
								break;
							end
							seekoff(-1)
							find_func = rfstr
							limit = -(0x10000)
							print("0000")
						else
							break
						end
					end
				end		
			elseif type(c[2]) == "number" then
				local find_func = fbyte
				local limit = 0x10000
				local address = tonumber(c[3]) or 0
				seek(address)
				
				if c[2] > 0xff then
					print("char should be [0, 0xff]")
				end
				
				while true do
					if find_func(c[2], true, limit) == false then
						print("not found ["..hexstr(c[2]).."]")
						break;
					else
						print("found ["..hexstr(c[2]).."]")
						dump()
						print("n:next, p:prev")
						local c = io.read()
						if c == "n"  then
							if get_size() <= cur() then
								print("[EOS]")
								break;
							end
							seekoff(1)
							find_func = fbyte
							limit = 0x10000
						elseif c == "p"  then
							if cur() <= 0then
								print("[pos=0]")
								break;
							end
							seekoff(-1)
							find_func = rfbyte
							limit = -(0x10000)
						else
							break
						end
					end
				end		
			else
				print("invalid argment", c[2], c[3])
			end
		elseif c[1] == "dump" then
			if type(c[2]) == "number" or c[2] == nil then
				c[2] = c[2] or 0
				local dump_address = touint(c[2])
				local dump_size 
				if type(c[3]) == "number" then
					dump_size = touint(c[3])
				else
					dump_size = 128
				end
				repeat
					if  get_size() <= dump_address then
						print("[EOS]")
						break
					end
					seek(dump_address)
					dump(dump_size)
					print("n:next")
					dump_address = dump_address + dump_size
				until io.read() ~= "n"
			else
				local data = get_data()
				local vs, ts, bytes, sizs, streams = data.values, data.tables, data.bytes, data.sizes, data.streams
				local dump_all = nil
				--if c[3] == nil then
				--	print("no index. dump for all data? [y/n]")
				--	if io.read() == "y" then
						dump_all = true
				--	else
				--		dump_all = false
				--	end
				--end
				if dump_all == nil then
					for k, v in pairs(vs) do
						if string.find(k, c[2]) ~= nil then
							if bytes[k] ~= nil and type(c[3]) == "number" then
								local ix = toindex(c[3], bytes[k])
								for i=1, 10000 do
									printf("  %s[%d]=%s size=%d in %s=%s",
										k, ix, ts[k][ix], sizs[k][ix], streams[k][ix].name, streams[k][ix].file_name)
									swap(streams[k][ix])
									seek(bytes[k][ix])
									dump(128)
									print("n:next, p:prev")
									local c = io.read()
									if c == "n" then
										if ix < #ts[k] then
											ix = ix+1
										else
											print("END")
											break
										end
									elseif c == "p" then
										if 0 < ix then
											ix = ix-1
										else
											print("index=0")
											break
										end
									else
										break
									end
								end
							end
						end
					end
				elseif dump_all == true then
					for k, _ in pairs(vs) do
						if string.find(k, c[2]) ~= nil then
							if bytes[k] ~= nil then
								local count = 0
								for i, v in ipairs(bytes[k]) do
									count = count + 1
									if count % 100 == 0 then
										print(k.."["..count.."]")
										print("n:next")
										if io.read() ~= "n" then
											break
										end
									end
									printf("  %s[%d]=%s size=%d in %s=%s",
										k, i, ts[k][i], sizs[k][i], streams[k][i].name, streams[k][i].file_name)
									swap(streams[k][i])
									seek(v)
									dump(64)
									print("")
								end
							end
						end
					end
				else
					print("abort.")
				end
			end
		elseif c[1] == "stream" then
			local streams = get_streams()
			for i, v in ipairs(streams) do
				print(i, v.name, v.file_name)
			end
			if type(c[2]) == "number" then
				print("swap("..streams[toindex(c[2], streams)].name..")")
				swap(streams[toindex(c[2], streams)])
			end
		elseif c[1] == "edit" then
			local cmdline = "\""..__hex_editor__.."\" "..__stream_path__
			print(cmdline)
			os.execute(cmdline)	
		elseif c[1] == "tedit" then
			local cmdline = "\""..__text_editor__.."\" "..__stream_path__
			print(cmdline)
			os.execute(cmdline)	
		elseif c[1] == "sql" then
			local cmd
			if windows then
				if c[2] == nil then
					os.execute("sqlite3.exe "..__out_dir__..__stream_name__..".db")
				else
					os.execute("sqlite3.exe "..c[2])
				end
			end	
		elseif c[1] == "dir" then
			local cmdline = "explorer \""..__exec_dir__.."\""
			print(cmdline)
			os.execute(cmdline)
		elseif c[1] == "test" then
			do
				local command = [[select * from bitstream limit 100]]
				local stmt = get_sql():prepare(command)
				sql_print(stmt)
			end

			do
				local command = [[select count(*), name from bitstream group by name limit 100]]
				local stmt = get_sql():prepare(command)
				print("num   |name")
				print("------|--------------------------")
				sql_print(stmt, "%6d| %-40s")
			end

			do
				local command = [[select name, count(*) from bitstream group by name limit 100]]
				local stmt = get_sql():prepare(command)
				sql_print(stmt)
			end
		elseif c[1] == "hogehoge" then
			elseif c[1] == "function" then
				if type(_G[c[2]]) == "table" then
					_G[c[2]](c[3], c[4], c[5], c[6], c[7], c[8], c[9])
				end
		else
			print("history              : show history")
			print("info                 : show all values")
			print("grep REGEX...        : search & show last value")
			print("list REGEX...        : search & show all value")
			print("dump REGEX [INDEX]   : hex dump around REGEX[INDEX]")
			print("dump ADDRESS         : hex dump from ADDRESS")
			print("find PATTERN ADDRESS : find PATTERN from ADDRESS, e.g. find \"00 00 01\" ")
			print("open FILENAME        : open newfile in stream directory")
			print("stream INDEX         : show and swap stream")
			print("edit                 : open stream by hex editor")
			print("tedit                : open stream by text editor")
			print("sql                  : open database by SQLite shell")
			print("dir                  : open .exe directory")
			print("test                 : test command")
			print("q|exit               : exit command mode")
		end
	until true
end

function parse_cmd(input)
	local c = {}
	local str
	--for tok in string.gmatch(input, "\"(.+?)\"|([^ ]+)") do
	for tok in string.gmatch(input, "([^\t ]+)") do
		-- ""������
		if tok:sub(1,1) == "\"" then
			str = tok:sub(2).." "
			if tok:sub(-1) == "\"" then
				table.insert(c, tok:sub(2,-2))
				str = nil
			end
		elseif tok:sub(-1) == "\"" then
			str = (str or "")..tok:sub(1, -2)
			table.insert(c, str)
			str = nil
		elseif str ~= nil then
			str = str..tok.." "
		else
			local num = tonumber(tok)
			if num ~= nil then
				table.insert(c, num)
			else
				table.insert(c, tok)
			end
		end
	end
	if #c >= 1 then
		table.insert(history, input)
		return c
	else
		return nil
	end
end

function cmd()
	local input

	print("<< command mode : \"q\" to exit >>")
	while true do
		io.write("cmd>")
		input = io.read()
		if input == "q"
		or input == "exit" then
			break
		else
			local c = parse_cmd(input)
			if c ~= nil then
				exec_cmd(c)
			end
		end
	end
end
