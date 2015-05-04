function printf(format, ...)
	print(string.format(format, ...))
end

function print_table(table)
	if table ~= nil then
		for i, v in ipairs(table) do
			print(i, v)
		end
		for k, v in pairs(table) do
			print(k, v)
		end
	else
		print("--talbe = nil --")
	end
end

function print_table_all(table)
	print("--table--")
	print_table(table)
	meta = getmetatable(table)
	if meta ~= nil then
		print_table(meta)
	else
		print("--no meta--")
	end
end


function check(name, length, disp_enable)
	value = readbyte(name, length, disp_enable)
	return {value = value}
end
