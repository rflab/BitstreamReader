-- CSVファイル出力ストリーム

local name = ...           -- 第一引数がモジュール名
local _m = {}              -- メンバ関数を補樹威するテーブル
local _meta = {__index=_m} 
local _v = {}              -- プライベート変数(selfをキーとするテーブル)
package.loaded[name] = _m  -- 二度目のrequire()はこれが返される
_G[name] = _m              -- グローバルに登録しておく

------------------------------------------------
-- private
------------------------------------------------

-- csv変換
-- 無名2次元配列はうまく処理できない
local save_as_csv_recursive_ipairs
local function save_as_csv_recursive(fp, tbl)
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
end
save_as_csv_recursive_ipairs = function (fp, tbl)
	for i, v in ipairs(tbl) do
		if type(v) == "table" then
			save_as_csv_recursive(fp, v)
		elseif v == false then
			fp:write(", ")
		else
			fp:write(tostring(v)..", ")
		end
	end
	fp:write("\n")
end

-- CSV出力用に2次元配列に変換する
-- rootに数値インデックスのテーブルが入っていた場合は"[1]"のような名前をつける
-- rootのテーブル中にテーブルが入っていた場合は再起して次の列に出力する
--   →ただしこの場合テーブルと値が混ざっている場合は順番は保証されない
local normalize_table_ipairs
local function normalize_table(tbl, dest, name)
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
end
normalize_table_ipairs = function (tbl, dest, name)
	local t = {name}
	for i, v in ipairs(tbl) do
		if type(v) == "table" then
			normalize_table(v, dest, name.."/["..i.."]")
		else
			table.insert(t, v)
		end
	end
	table.insert(dest, t)
end

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
end

-- テーブルの転置
local function transpose_table(tbl, dest)
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

------------------------------------------------
-- public
------------------------------------------------

function _m:new ()
	obj = {tbl={}}
	--_v[obj] = {}
	setmetatable(obj, _meta)
	return obj
end

-- table[name]に値を保存二度目以降はテーブルになる、最初からテーブルを追記も可
-- falseを書いた欄はcsv上では空欄になる
function _m:insert(name, value)
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
end

function _m:save(file_name, ...)
	fp = io.open(file_name, "w") or io.open("_"..file_name, "w")
	assert(fp, "fileopen error save_as_csv("..file_name..")")
	save_as_csv_recursive(
		fp,
		transpose_table(select_table(normalize_table(self.tbl),	... or "all")))
end

