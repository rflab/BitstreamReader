function printf(format, ...)
	print(string.format(format, ...))
end

function dump_table(table)
	if table ~= nil then
		for i, v in ipairs(table) do
			print("", i, v)
		end
		for k, v in pairs(table) do
			print("", k, v)
		end
	else
		print("--talbe = nil --")
	end
end

function dump_table_all(table)
	local t = type(table)
	print("--"..t.."--")
	if t == "table" then
		dump_table(table)
	end
	
	meta = getmetatable(table)
	if meta ~= nil then
		print("--metatable--")
		dump_table(meta)
	else
		print("--no metatable--")
	end
end


function check(name, length, disp_enable)
	value = readbyte(name, length, disp_enable)
	return {value = value}
end
