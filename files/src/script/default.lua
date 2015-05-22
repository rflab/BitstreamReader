-- ライブラリロード
dofile("script/module/util.lua")

-- 各種値定義
assert(argv[1], "no file name in argv[1]") 
__stream_path__ = argv[1] 
__stream_ext__  = string.gsub(argv[1], ".*(%..*)", "%1")
--__stream_name__ = string.gsub(argv[1], "(?!.*/).", "%1")
__stream_name__ = string.gsub(argv[1], ".*/(.*)%..*$", "%1")

print("###########", __stream_name__)

-- 拡張子にあわせてスクリプト実行
local ext = __stream_ext__
if ext == ".wav" then
	dofile("script/wav.lua")

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

elseif string.match(argv[1], "[0-9][0-9] ") ~= nil then
	dofile("script/numeric_string.lua")

else
	print("not found extension")
end
