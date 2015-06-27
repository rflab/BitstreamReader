local history = {}

function exec_cmd(c)
	if c[1] == "history" then
		print_table(history)
	elseif c[1] == "list" then
		local vs, ts = get_tbl()
		for k, v in pairs(vs) do
			local num = ts[k] and #(ts[k]) or 0
			printf("  %-50s %-8s [%d]", k, v, num)
		end
	elseif c[1] == "grep" then
		local vs, ts = get_tbl()
		for i = 2, #c do
			print("["..c[i].."]")
			for k, v in pairs(vs) do
				if string.find(k, c[i]) ~= nil then
					local num = ts[k] and #(ts[k]) or 0
					printf("  %-50s %-8s [%d]", k, v, num)
				end
			end
		end
	elseif c[1] == "dump" then
		local vs, ts = get_tbl()
		local dump_continue = nil
		for i = 2, #c do
			print("["..c[i].."]")
			for k, v in pairs(vs) do
				if string.find(k, c[i]) ~= nil then
					local num = ts[k] and #(ts[k]) or 0
					printf("  %s[%d]", k, num)
					local t = ts[k]
					if type(t) == "table" then
						if #t > 10 then
							if dump_continue == nil then
								print("table size is ".. #t..", continue? [y/n]")
								if io.read() == "y" then
									dump_continue = true
									print_table(t, 2)
								else
									dump_continue = false
									print("    give up dump.")
								end
							elseif dump_continue == false then
								print("    give up dump.")
							elseif dump_continue == true then
								print_table(t, 2)
							end
						else
							print_table(t, 2)
						end
					end
					print("")
				end
			end
		end
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	--	elseif c[1] == "function" then
	--		if type(_G[c[2]]) == "table" then
	--			_G[c[2]](c[3], c[4], c[5], c[6], c[7], c[8], c[9])
	--		end
	else
		print("history           : show history")
		print("list              : show all values")
		print("grep [PATTARN...] : search & show last value")
		print("dump [PATTARN...] : search & show all value")
		print("q                 : exit command mode")
	end
end

function parse_cmd(input)
	local c = {}
	for tok in string.gmatch(input, "([^ ]+)") do
		local num = tonumber(tok)
		if num ~= nil then
			table.insert(c, num)
		else
			table.insert(c, tok)
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
		input = io.read()
		if input == "q" then
			break
		else
			local c = parse_cmd(input)
			if c ~= nil then
				exec_cmd(c)
			end
		end
	end
end
