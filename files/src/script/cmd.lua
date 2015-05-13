function split(str, delim)                                                                                                                                    
	assert(str,  "�����񂪐ݒ肳��Ă��܂���")
	assert(delim,"��؂蕶�������Ă�����Ă��܂���")
	local pattern = "[^"..delim.."]*"..delim

	local result = {}
	for item in string.gmatch(str, pattern) do
		local tmp = item:gsub(delim,"")
		table.insert(result, tmp)
	end 
	return result
end

function getPid(name)
	local command='pidof '..name
	local commandResult = execCommand(command)
	local result = string.gsub(commandResult, "\n", "") 
	return  result
end

function getDirList(dirname)
	local command='find '..dirname..' -type d'
	local commandResult = execCommand(command)
	local result = string.gsub(commandResult, "\n", ",")
	return split(result, ",")
end

function execCommand(command)
	local handle = io.popen(command,"r")
	local content = handle:read("*all")
	handle:close()
	return content
end