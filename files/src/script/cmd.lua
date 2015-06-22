local history = {}

function exec_cmd(c)
	if c[1] == "help"
	or c[1] == "h" then
		print("history :show history")
		print("get     :search & show value by part of value name")
		print("all     :show all values")
	elseif c[1] == "history" then
		print_table(history)
	elseif c[1] == "get" then
		for i = 2, #c do
			print("["..c[i].."]")
			for k, v in pairs(get_tbl()) do
				if string.find(k, c[i]) ~= nil then
					print("    "..k.." = "..v)
				end
			end
		end
	elseif c[1] == "all" then
		print_table(get_tbl())
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	elseif c[1] == "hogehoge" then
	else
		_G[c[1]](c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
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
	
	print("<< command mode : \"h\" to help, \"q\" to exit >>")
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
