local history = {}

function exec_cmd(cmd_str)
	local c = parse_cmd(cmd_str)
	if c == nil then
		return
	end

	repeat
		if c[1] == "history" then
		
			print_table(history)
		
		elseif c[1] == "open" then
		
			if type(c[2]) == "string" then
				open(__stream_dir__..c[2])
			end
		
		elseif c[1] == "info" then

			local command = [[
				select main_byte, count(*), name, id, value
				from bitstream
				group by name;]]
			local stmt = sql_prepare(command)
			print("------------  ---------  ---------------------------------------  -------  ----------")
			print("offset        count      name                                     last_id  last_value")
			print("------------  ---------  ---------------------------------------  -------  ----------")
			sql_print(stmt, "  0x%08x %10d  %-40s %7d  %-8s")
			print("")
			print_status()
						
		elseif c[1] == "grep" then
		
			if c[2] == nil then
				print("error:keyword REGEX")
				break
			end
			
			if tonumber(c[3]) == nil then
				c[3] = 0
			end
			
			if tonumber(c[4]) == nil then
				c[4] = 20
			end
			
			local command = [[
				select main_byte, count(*), name, id, value
				from bitstream
				where name like "%]]..c[2]..[[%" 
				group by name
				limit ]]..tonumber(c[3])..", "..tonumber(c[4])..[[;]]
			local stmt = sql_prepare(command)
			print("------------  ---------  ---------------------------------------  -------  ----------")
			print("offset        count      name                                     last_id  last_value")
			print("------------  ---------  ---------------------------------------  -------  ----------")
			sql_print(stmt, "  0x%08x %10d  %-40s %7d  %-8s")
			
		elseif c[1] == "list" then
		
			if c[2] == nil then
				print("error:keyword REGEX")
				break
			end

			if tonumber(c[3]) == nil then
				c[3] = 0
			end
			
			if tonumber(c[4]) == nil then
				c[4] = 20
			end
			
				
			local command = [[
				select *
				from bitstream
				where name like "%]]..c[2]..[[%"
				limit ]]..tonumber(c[3])..", "..tonumber(c[4])..[[;]]
			local stmt = sql_prepare(command)

			print("-------  ------------------------  ----------  ----------  ---  ----------  ------------")
			print("id       name                      main_byte   byte        bit  size        value")
			print("-------  ------------------------  ----------  ----------  ---  ----------  ------------")
			sql_print(stmt, "%7d  %-25s 0x%08x  0x%08x  %3d %11d %13s")
		
		elseif c[1] == "view" then
			
			if tonumber(c[2]) == nil then
				c[2] = 0
			end
			
			if tonumber(c[3]) == nil then
				c[3] = 20
			end

			local command = [[
				select *
				from bitstream
				limit ]]..tonumber(c[2])..", "..tonumber(c[3])..[[;]]
			local stmt = sql_prepare(command)

			print("-------  ------------------------  ----------  ----------  ---  ----------  ------------")
			print("id       name                      main_byte   byte        bit  size        value")
			print("-------  ------------------------  ----------  ----------  ---  ----------  ------------")
			sql_print(stmt, "%7d  %-25s 0x%08x  0x%08x%3d %13d %13s")
		
		elseif c[1] == "xmlexport" then
			
			if type(c[2]) ~= "string" then
				print("error:xml no filename")
				break
			end
			
			local fp = io.open(__out_dir__..c[2], "w")
			if fp == nil then
				print("xmlexport open error")
				break
			end
			
			fp:write("<MediaInfo file=\""..__stream_name__..__stream_ext__.."\">\n")
			local command = [[
				select *
				from bitstream;]]
			local stmt = sql_prepare(command)
			
			local name
			local value
			local tag_stack = {"MediaInfo"}
			local indent_str = "	"
			while sql_step(stmt) do
				name = sql_column(stmt, 1) 
				value = sql_column(stmt, 6)
				if value == "push" then
					fp:write(indent_str.."<"..name..">\n")
					table.insert(tag_stack, name)
					indent_str = string.rep("	", #tag_stack)
				elseif value == "pop" then
					table.remove(tag_stack)
					indent_str = string.rep("	", #tag_stack)
					fp:write(indent_str.."</"..name..">\n")
				else 
					-- なにもpushされていなければ追記しない
					if (#tag_stack >= 2)
					then
						fp:write(indent_str.."<"..string.gsub(name, "[^0-9a-zA-Z_]", "_").." value=\""..value.."\"/>\n")
					end
				end
			end
			
			while #tag_stack > 0 do
				if #tag_stack >= 2 then
					print("# unclosed tree")
					print("</"..tag_stack[#tag_stack]..">")
				end
				fp:write("</"..tag_stack[#tag_stack]..">\n")				
				table.remove(tag_stack)
			end
			fp:close()
			
		elseif c[1] == "export" then
		
			if type(c[2]) ~= "string" then
				print("error:no filename")
				break
			end
			
			if c[3] == nil then
				c[3] = ""
			end

			local command = [[
				select *
				from bitstream
				where name like "%]]..c[3]..[[%";]]
			local stmt = sql_prepare(command)

			-- 追加するか確認（出力ファイルがすでにあるか）
			local file_exits = io.open(__out_dir__..c[3], "r")
			
			if file_exits ~= nil then 
				file_exits:close()
			end
			
			-- ここに書き出し
			local fp
			if file_exits ~= nil then
				print("log file already exists. add record? [y/n (default:n)]")
				if io.read() == "y" then
					print("add record")
					fp = io.open(__out_dir__..c[2], "a")
					if fp == nil then
						print("export open error1")
						break
					end
				else
					print("overwrite")
					fp = io.open(__out_dir__..c[2], "w")
					if fp == nil then
						print("export open error2")
						break
					end
					fp:write("id, name, main_byte, byte, bit, size, value\n")
				end
			else
				fp = io.open(__out_dir__..c[2], "w")
				if fp == nil then
					print("export open error3")
					break
				end
				fp:write("id, name, main_byte, byte, bit, size, value\n")
			end
			
			sql_print(stmt, "%d,%s,%d,%d,%d,%d,%s\n", fp)
			fp:close()
			
		elseif c[1] == "find" then
			
			if type(c[2]) == "string" then
			
				local address = tonumber(c[3]) or 0
				seek(address)

				local direction = "n"
				while true do
					if direction == "n"  then
						local ofs = fstr(c[2], 0x10000, true)
						if ofs == 0x10000 then
							print("not found ["..c[2].."]")
							break;
						end
						if get_size() <= cur() then
							print("[EOS]")
							break;
						end
						print("found ["..c[2].."]")
						dump()
					elseif direction == "p" then
						local ofs = rfstr(c[2], -(0x10000), true)
						if ofs == -(0x10000) then
							print("not found ["..c[2].."]")
							break;
						end
						if cur() <= 0 then
							print("[pos=0]")
							break;
						end
						print("found ["..c[2].."]")
						dump()
					end

					print("n:next, p:prev")
					direction = io.read()
					if direction == "n" then
						seekoff(1)
					elseif direction == "p" then
						seekoff(-1)
					else
						break
					end
				end
				
			elseif type(c[2]) == "number" then
             
			 	local address = tonumber(c[3]) or 0
			 	seek(address)
			 	
			 	if c[2] > 0xff then
			 		print("char should be [0, 0xff]")
			 	end
			 	
				local direction = "n"
			 	while true do
					if direction == "n"  then
						local ofs = fbyte(c[2], 0x10000, true)
						if ofs == 0x10000 then
							print("not found ["..c[2].."]")
							break;
						end
						if get_size() <= cur() then
							print("[EOS]")
							break;
						end
						print("found ["..c[2].."]")
						dump()
					elseif direction == "p" then
						local ofs = rfbyte(c[2], -(0x10000), true)
						if ofs == -(0x10000) then
							print("not found ["..c[2].."]")
							break;
						end
						if cur() <= 0 then
							print("[pos=0]")
							break;
						end
						print("found ["..c[2].."]")
						dump()
					else
						break
					end
					
					print("n:next, p:prev")
					direction = io.read()
					if direction == "n" then
						seekoff(1)
					elseif direction == "p" then
						seekoff(-1)
					else
						break
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

			elseif type(c[2]) == "string" then
				
				if tonumber(c[3]) == nil then
					c[3] = 1
				end
			
				if tonumber(c[4]) == nil then
					c[4] = 10
				end
	
				local command = [[
					select name, main_byte, byte, bit, size
					from bitstream
					where name like "%]]..c[2]..[[%"
					limit ]]..tonumber(c[3])..", "..tonumber(c[4])..[[;]]
				local stmt = sql_prepare(command)
				while sql_step(stmt) do
					local name = sql_column(stmt, 0)
					local main_byte = sql_column(stmt, 1)
					local byte = sql_column(stmt, 2)
					local bit = sql_column(stmt, 3)
					local size = sql_column(stmt, 4)
					
					-- とりあえずこうやってメインのストリームかを判定する
					if main_byte == byte then
						get_main_stream():seek(main_byte)
						if size ~= 0 then
							printf("\n  [%s] main_byte=%x byte=%x(+%d) size=0x%x(+%d)", name, main_byte, byte, bit, size>>3, size%8)
							get_main_stream():dump((size+7)>>3)
						else
							printf("\n  <%s> main_byte=%x byte=%x(+%d) size=0(TAG)", name, main_byte, byte, bit)
							get_main_stream():dump(0x30)
						end
					else
						print("dump of sub stream is unsupported")
					end
				end
				
			else
			
				print("REGEX error")

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
	
		elseif c[1] == "function" then
			if type(_G[c[2]]) == "table" then
				_G[c[2]](c[3], c[4], c[5], c[6], c[7], c[8], c[9])
			end
		else

			print("-----------")
			print("global info")
			print("-----------")
			print("history                     : show history")
			print("info                        : show record information")
			print("view [FROM] [LIMIT]         : show records")
			print("grep {REGEX} [FROM] [LIMIT] : show records by regex")
			print("list {REGEX} [FROM] [LIMIT] : show record list by regex")
			print("export {FILENAME} [REGEX]   : export records to csv file")
			print("xmlexport {FILENAME}        : export records to xml file")
			print("")
			print("------------------------")
			print("current stream operation")
			print("------------------------")
			print("open {FILENAME}             : open newfile in stream directory")
			print("stream [INDEX]              : show and swap stream")
			print("dump {REGEX} [FROM] [LIMIT] : dump by grep")
			print("dump {OFFSET}               : dump from OFFSET")
			print("find {PATTERN} {OFFSET}     : find byte or PATTERN from OFFSET, e.g. find \"00 00 01\" ")
			print("")
			print("------------------------")
			print("others")
			print("------------------------")
			print("edit                        : open stream by hex editor")
			print("tedit                       : open stream by text editor")
			print("sql                         : open database")
			print("dir                         : open .exe directory")
			print("test                        : test command")
			print("exit                        : exit command mode")
			print("q                           : exit command mode")

		end
	until true
end

-- 現在使っていない
-- 初期のコードで以下のような記録をする場合の
-- if gs_global.store_lua == true then
-- 	if gs_data.tables[name] == nil then
-- 		gs_data.tables[name]  = {}
-- 		gs_data.bytes[name]   = {}
-- 		gs_data.bits[name]    = {}
-- 		gs_data.sizes[name]   = {}
-- 		gs_data.streams[name] = {}
-- 	end
-- 	
-- 	table.insert(gs_data.bytes[name], byte)
-- 	table.insert(gs_data.bits[name], bit)
-- 	table.insert(gs_data.tables[name], value)
-- 	table.insert(gs_data.sizes[name], size)
-- 	table.insert(gs_data.streams[name], gs_cur_stream)
-- else
-- 	local cnt = gs_data.skipcnt[name] or 0
-- 	gs_data.skipcnt[name] = cnt + 1 
-- end
function old_exec_cmd(cmd)
	local c = parse_cmd(cmd)
	if c == nil then
		return
	end

	repeat
		if c[1] == "grep_old" then

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
		
		elseif c[1] == "info_old" then
		
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
		
		elseif c[1] == "list_old" then
		
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
									print("table size is ".. #t..", continue? [y/n (default:n)]")
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

			elseif type(c[2]) == "string" then
				
				if tonumber(c[3]) == nil then
					c[3] = 1
				end
			
				if tonumber(c[4]) == nil then
					c[4] = 10
				end
	
				local command = [[
					select name, main_byte, byte, bit, size
					from bitstream
					where name like "%]]..c[2]..[[%"
					limit ]]..tonumber(c[3])..", "..tonumber(c[4])..[[;]]
				local stmt = sql_prepare(command)
				while sql_step(stmt) do
					local name = sql_column(stmt, 0)
					local main_byte = sql_column(stmt, 1)
					local byte = sql_column(stmt, 2)
					local bit = sql_column(stmt, 3)
					local size = sql_column(stmt, 4)
					printf("\n  [%s] main_byte=%x byte=%x(+%d) size=0x%x(+%d)", name, main_byte, byte, bit, size>>3, size%8)
					get_main_stream():seek(main_byte)
					get_main_stream():dump((size+7)>>3)
				end

			else

				local data = get_data()
				local vs, ts, bytes, sizs, streams = data.values, data.tables, data.bytes, data.sizes, data.streams
				local dump_all = nil
				--if c[3] == nil then
				--	print("no index. dump for all data? [y/n (default:n)]")
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
			
		end
	until true
end

function parse_cmd(cmd)
	local c = {}
	local str
	--for tok in string.gmatch(cmd, "\"(.+?)\"|([^ ]+)") do
	for tok in string.gmatch(cmd, "([^\t ]+)") do
		-- ""文字列
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
		table.insert(history, cmd)
		return c
	else
		return nil
	end
end

function cmd()
	local c
	
	print("-----------------------------")
	print("command mode : q:quit, h:help")
	print("-----------------------------")
	while true do
		io.write("cmd>")
		c = io.read()
		if c == "q"
		or c == "exit" then
			break
		else
			exec_cmd(c)
		end
	end
end

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
