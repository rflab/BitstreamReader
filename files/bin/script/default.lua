-- ライブラリロード
dofile("script/mylib.lua")
-- dofile("script/cmd.lua")
-- dofile("script/explicit_globals.lua")
-- use_explicit_globals()

-- 拡張子にあわせてスクリプト実行
assert(arg1, "no file name in argv[1]") 
<<<<<<< HEAD
local ext = string.gsub(arg1, ".*(%..*)", "%1")
=======
local ext = string.gsub(filename, ".*(%..*)", "%1")
>>>>>>> origin/master
if ext == ".wav" then
	dofile("script/wav.lua")
else
	print("not found extension")
end
