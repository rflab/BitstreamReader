-- ライブラリロード
dofile("script/module/util.lua")

-- 各種値定義
assert(argv[1], "no file name in argv[1]") 
__stream_path__, __stream_name__, __stream_ext__ = split_file_name(argv[1])

-- 拡張子にあわせてスクリプト実行
local ext = __stream_ext__

if ext == ".wav" then
	dofile("script/wav.lua")
	
elseif ext == ".bmp" then
	dofile("script/bmp.lua")
	
elseif ext == ".jpg"
or     ext == ".JPG" then
	dofile("script/jpg.lua")
	
elseif ext == ".ts"
or     ext == ".tts"
or     ext == ".m2ts"
or     ext == ".mpg" then
	dofile("script/ts.lua")
	
elseif ext == ".pes" then
	dofile("script/pes.lua")

elseif ext == ".mp4" then
	dofile("script/mp4.lua")

elseif ext == ".dat" then
	dofile("script/dat.lua")

elseif string.match(argv[1], "[0-9a-f][0-9a-f]") ~= nil then
	dofile("script/string.lua")

else
	print("not found extension")
end
