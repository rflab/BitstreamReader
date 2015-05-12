-- ライブラリロード
dofile("script/mylib.lua")
-- dofile("script/cmd.lua")
-- dofile("script/explicit_globals.lua")
-- use_explicit_globals()

local ext = get_extension(arg1 or "test.wav")
if ext == ".wav" then
	dofile("script/wav.lua")
else
	print("not found extension")
end