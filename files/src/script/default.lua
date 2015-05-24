-- ライブラリロード
dofile(__exec_dir__.."script/module/util.lua")

-- 各種値定義
assert(argv[0], "no file name in argv[0]") 
assert(argv[1], "no file name in argv[1]") 
__exec_path__,   __exec_dir__,   __exec_name__,   __exec_ext__   = split_file_name(argv[0])
__stream_path__, __stream_dir__, __stream_name__, __stream_ext__ = split_file_name(argv[1])
-- print("__exec_path__  :"..__exec_path__)
-- print("__exec_dir__   :"..__exec_dir__)
-- print("__exec_name__  :"..__exec_name__)
-- print("__exec_ext__   :"..__exec_ext__)
-- print("__stream_path__:"..__stream_path__)
-- print("__stream_dir__ :"..__stream_dir__)
-- print("__stream_name__:"..__stream_name__)
-- print("__stream_ext__ :"..__stream_ext__)


-- 拡張子にあわせてスクリプト実行
local ext = __stream_ext__

if ext == ".wav" then
	dofile(__exec_dir__.."script/wav.lua")
	
elseif ext == ".bmp" then
	dofile(__exec_dir__.."script/bmp.lua")
	
elseif ext == ".jpg"
or     ext == ".JPG" then
	dofile(__exec_dir__.."script/jpg.lua")
	
elseif ext == ".ts"
or     ext == ".tts"
or     ext == ".m2ts"
or     ext == ".mpg" then
	dofile(__exec_dir__.."script/ts.lua")
	
elseif ext == ".pes" then
	dofile(__exec_dir__.."script/pes.lua")

elseif ext == ".mp4" then
	dofile(__exec_dir__.."script/mp4.lua")

elseif ext == ".dat" then
	dofile(__exec_dir__.."script/dat.lua")

elseif string.match(argv[1], "[0-9a-f][0-9a-f]") ~= nil then
	dofile(__exec_dir__.."script/string.lua")

else
	print("not found extension")
end
