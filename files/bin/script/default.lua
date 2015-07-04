-- ライブラリロード
dofile(__exec_dir__.."script/module/util.lua")
dofile(__exec_dir__.."script/cmd.lua")
dofile(__exec_dir__.."script/check_stream.lua")

-- 各種値定義
assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")
__exec_path__, __exec_dir__, __exec_name__, __exec_ext__ = split_file_name(argv[0])
__stream_path__, __stream_dir__, __stream_name__, __stream_ext__ = split_file_name(argv[1])
-- print("__exec_path__  :"..__exec_path__)
-- print("__exec_dir__   :"..__exec_dir__)
-- print("__exec_name__  :"..__exec_name__)
-- print("__exec_ext__   :"..__exec_ext__)
-- print("__stream_path__:"..__stream_path__)
-- print("__stream_dir__ :"..__stream_dir__)
-- print("__stream_name__:"..__stream_name__)
-- print("__stream_ext__ :"..__stream_ext__)

-- 解析結果出力先ディレクトリ作成
if windows then
	os.execute("mkdir \""..__stream_dir__.."out\"")
else
	os.execute("mkdir -p \""..__stream_dir__.."out/\"")
end

-- SQLトランザクション開始
sql_begin()

-- 解析ディスパッチ
local stream = open(__stream_path__)
local stream_type = check_stream(stream)
local ext = stream_type or __stream_ext__

if __stream_ext__ == ".test" then
	dofile(__exec_dir__.."script/test.lua")

elseif ext == ".wav" then
	dofile(__exec_dir__.."script/wav.lua")
	
elseif ext == ".bmp" then
	dofile(__exec_dir__.."script/bmp.lua")
	
elseif ext == ".jpg"
or     ext == ".JPG" then
	dofile(__exec_dir__.."script/jpg.lua")
	
elseif ext == ".ts"
or     ext == ".tts"
or     ext == ".m2ts"
or     ext == ".MPG"
or     ext == ".mpg" then
	dofile(__exec_dir__.."script/ts.lua")
	
elseif ext == ".pes" then
	dofile(__exec_dir__.."script/pes.lua")

elseif ext == ".h264" then
	dofile(__exec_dir__.."script/h264.lua")

elseif ext == ".h265" then
	dofile(__exec_dir__.."script/h265.lua")

elseif ext == ".mp4" then
	dofile(__exec_dir__.."script/mp4.lua")

elseif ext == ".dat" then
	dofile(__exec_dir__.."script/dat.lua")
	
elseif string.match(argv[1], "^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
	dofile(__exec_dir__.."script/string.lua")

elseif ext == ".txt" then
	dump(256)
	
else
	print("not found extension")
end

-- SQLトランザクション終了
sql_commit()

-- 解析コマンド起動
cmd()