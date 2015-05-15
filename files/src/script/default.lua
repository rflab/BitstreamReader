-- ライブラリロード
dofile("script/util.lua")
-- dofile("script/cmd.lua")
-- dofile("script/explicit_globals.lua")
-- use_explicit_globals()

-- 拡張子にあわせてスクリプト実行
assert(argv[1], "no file name in argv[1]") 
local ext = string.gsub(argv[1], ".*(%..*)", "%1")
if ext == ".wav" then
	dofile("script/wav.lua")
elseif ext == ".dat" then
	dofile("script/dat.lua")
elseif string.match(argv[1], "[0-9][0-9] ") ~= nil then
	dofile("script/numeric_string.lua")
else
	print("not found extension")
end

