

--[[
---------------------------
-- util.luaの内部クラス
---------------------------
gs_stream = nil
gs_csv = nil

-- ストリーム
Stream = {
	new = function (file_name)
			print("open_stream("..file_name..")")

			local obj = {tbl={}}
			obj.file_name = file_name
			obj.stream = Bitstream.new()
			assert(obj.stream:open(file_name))
			obj.file_size = gs_stream.stream:file_size()
			setmetatable(obj, {__index = Stream})
			return obj
		end,
	print = function()	
			printf("file_name:%s", gs_stream.status.file_name)
			printf("file_size:0x%08x", file_size())
			printf("cursor   :0x%08x(%d)", cur(), cur())
			printf("remain   :0x%08x", file_size() - cur())
		end,
	size = function(self)	
			return self.stream:file_size()
		end,
	dump = function(self)	
			gs_stream.stream:dump(256)
		end,
	cur = function(self)	
			return self.stream:cur_byte(), self.stream:cur_bit()
		end,
	get = function(self, name)	
			return self.tbl[name]
		end,
	rbit = function(self, name, size)
			local val = self.stream:read_bit(name, size)
			.check(val, "rbit:"..name)
			self.tbl[name] = val
			return val
		end,
	rbyte = function(self, name, size)	
			local val = self.stream:read_byte(name, size)
			self.on_read(val, "rbyte:"..name)
			self.tbl[name] = val
			return val
		end,
	rstr = function(self, name, size)	
		 	local val = self.stream:read_string(name, size)
			self.on_read(val, "rstr:"..name)
			self.tbl[name] = val
			return val
		end,
	cbit = function(self, name, size)	
			local val = self.stream:comp_bit(name, size, comp)
			self.on_read(val, "cbit:"..name)
			self.tbl[name] = val
			return val
		end,
	cbyte = function(self, name, size)	
			local val = self.stream:comp_byte(name, size, comp)
			self.on_read(val, "cbyte:"..name)
			self.tbl[name] = val
			return val
		end,
	cstr = function(self, name, size)	
		 	local val = self.stream:comp_string(name, size, comp)
			self.on_read(val, "cstr:"..name)
			self.tbl[name] = val
			return val
		end,
	sbyte = function(self, name, size)	
			local ofs = self.stream:search_byte(char)
			self.on_read(ofs, "sbyte:"..char)
			return ofs
		end,
	sstr = function(self, name, pattern)
			local str = ""
			if string.match(pattern, "[0-9][0-9] ") ~= nil then
				for hex in string.gmatch(pattern, "%w+") do
					str = str .. string.char(tonumber(hex, 16))
				end
			else
				str = pattern
			end
			local ofs = self.stream:search_byte_string(str, #str)
			on_read(ofs, "sstr:"..pattern)
			return ofs	
		end,
	offset = function(self, ofs)
			self.stream:offset_byte(ofs)
		end
	seek = function(self, pos)
			return self.stream:seek(pos, 0)
		end,
	wbyte = function(self, filename, size)	
			local ret = self.stream:copy_byte(filename, size)
			on_read(ret, "wbyte:"..filename)
		end,
	write = function(self, filename, pattern)
			local str = ""
			if string.match(pattern, "[0-9][0-9] ") ~= nil then
				for hex in string.gmatch(pattern, "%w+") do
					str = str .. string.char(tonumber(hex, 16))
				end
			else
				str = pattern
			end
			local ret = self.stream:write(filename, str, #str)
			on_read(ret, "write:"..filename)
		end,
	enable_print = function(self, b)	
			return self.stream:enable_print(b)
		end,
	bit_seek = function(self, size)	
			return self.stream:offset_by_bit(size)
		end
	set_exit = function(self, address)	
			self.break_address = address
		end,
	check = function(self, result, msg)
		if gs_break_address ~= nil then
			if cur() > self.break_address - 127 then
				print_on(true)
			end
			if cur() > self.break_address + 126 then
				assert(false)
			end
		end

		if result == false or result == nil then
			print_table(self.tbl)
			self:offset_byte(-127)
			self:dump()
			assert(false, "assert on_read msg=".. msg)
		end
	end,
	--function progress()
	--	local p = math.modf(cur()/file_size() * 100)
	--	if math.modf(p % 10) == 0 and progress <= p then
	--		gs_prev_progress = gs_prev_progress + 10
	--		print(progress.."%", os.clock().."sec.")
	--		profiler:print()
	--	end
	--end
}

-- CSV出力ストリーム
Csv = {
	new = function ()
		obj = {tbl={}}
		setmetatable(obj, {__index=Csv})
	end,
	insert = function insert(self, name, value)
			assert(name ~= nil, "nil name specified")
			assert(value ~= nil, "nil value specified")

			if type(self.tbl[name]) == "table" then
				table.insert(self.tbl[name], value)
			elseif self.tbl[name] == nil then
				self.tbl[name] = value
			else
				local prev_value = self.tbl[name]
				self.tbl[name] = {prev_value, value}
			end
		end,
	save_as_csv = function (self, file_name, ...)
			fp = io.open(file_name, "w") or io.open("_"..file_name, "w")
			assert(fp, "fileopen error save_as_csv("..file_name..")")
			Csv.save_as_csv_recursive(
				fp,
				transpose_table(select_table(normalize_table(self.tbl),
				... or "all")))
		end

	-- csv変換
	-- 無名2次元配列はうまく処理できない
	function save_as_csv_recursive(fp, tbl)
		save_as_csv_recursive_ipairs(fp, tbl)
		for k, v in pairs(tbl) do
			if type(k) == "string" then
				fp:write("["..k.."]"..", ")
				if type(v) == "table" then
					save_as_csv_recursive(fp, v)
				else
					fp:write(tostring(v)..",\n")
				end
			end
		end
	end,
	function save_as_csv_recursive_ipairs(fp, tbl)
		for i, v in ipairs(tbl) do
			if type(v) == "table" then
				save_as_csv_recursive(fp, v)
			else
				fp:write(tostring(v)..", ")
			end
		end
		fp:write("\n")
	end,
	
	-- CSV出力用に2次元配列に変換する
	-- 配列中にテーブルが出てきた場合は再起して出力する
	-- テーブルと値が混ざっている場合は順番は保証されない
	function normalize_table(tbl, dest, name)
		dest = dest or {}
		name = name or ""
		normalize_table_ipairs(tbl, dest, name)
		for k, v in pairs(tbl) do
			if type(k) == "string" then
				if type(v) == "table" then
					normalize_table(v, dest, name.."/"..k)
				else
					table.insert(dest, {name.."/"..k, v})
				end
			end
		end
		return dest
	end,
	function normalize_table_ipairs(tbl, dest, name)
		local t = {name}
		for i, v in ipairs(tbl) do
			if type(v) == "table" then
				normalize_table(v, dest, name.."/["..i.."]")
			else
				table.insert(t, v)
			end
		end
		table.insert(dest, t)
	end,

	-- テーブルの先頭要素もしくはキーにパターンが一致するテーブルだけを抽出する
	function select_table(tbl, ...)
		assert(type(tbl) == "table", "tbl should be table.")
		if "all" == ... then
			return tbl
		end
		dest = {}
		n = {...}
		for i1, v1 in ipairs(n) do
			for k2, v2 in pairs(tbl) do
				if string.match(k2, v1)
				or type(v2) == "table" and type(v2[1]) == "string" and string.match(v2[1], v1) then
					table.insert(dest, v2)
				end
			end
		end
		return dest
	end,

	-- テーブルの転置
	function transpose_table(tbl, dest)
		dest = dest or {}
		local colmuns = {}
		local max_row = 0
		local num_colmuns = 0
		for k, v in pairs(tbl) do
			if type(v) == "table" then
				num_colmuns = num_colmuns + 1
				max_row = math.max(#v, max_row)
				table.insert(colmuns, v)
			end
		end
		for i=1, max_row do
			table.insert(dest, {})
			for j=1, num_colmuns do
				dest[i][j] = colmuns[j][i] or ""
			end
		end
		return dest
	end
}

-- 時間プロファイラ
Profiler = {
	new = function ()
		local obj = {}	
		setmetatable(obj, {__index = Profiler})
		return obj
	end,
	enter = function (self, name)
		self[name] = self[name] or {total_time=0, prev_time=0, count=0}
		self[name].prev_time = os.clock()
		self[name].count = self[name].count + 1
	end,
	leave = function (self, name)
		self[name].total_time = 
			self[name].total_time + (os.clock() - self[name].prev_time)
	end,
	print = function (self)
		for k, v in pairs(self) do
			print(k, "total:"..v.total_time, "count:"..v.count, "average:"..v.total_time/v.count)
		end
	end
}

--]]
