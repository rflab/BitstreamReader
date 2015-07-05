-- ライブラリロード
dofile(__exec_dir__.."script/util/include.lua")

-- 各種値定義
assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")
local ep, __, en, ee = split_file_name(argv[0])
local sp, sd, sn, se = split_file_name(argv[1])
global("__exec_path__",   ep)
global("__exec_name__",   en)
global("__exec_ext__",    ee)
global("__stream_path__", sp)
global("__stream_dir__",  sd)
global("__stream_name__", sn)
global("__stream_ext__",  se)

-- 解析結果出力先ディレクトリ作成
if windows then
	os.execute("mkdir \""..__stream_dir__.."out\"")
else
	os.execute("mkdir -p \""..__stream_dir__.."out/\"")
end

-- SQLトランザクション開始
sql_begin()

-- 解析ディスパッチ
local stream = open(__stream_path__, "rb")
local stream_type = check_stream(stream)
local ext = stream_type or __stream_ext__

if __stream_ext__ == ".test" then
	dofile(__exec_dir__.."script/streamdef/test.lua")

elseif ext == ".wav" then
	dofile(__exec_dir__.."script/streamdef/wav.lua")
	
elseif ext == ".bmp" then
	dofile(__exec_dir__.."script/streamdef/bmp.lua")
	
elseif ext == ".jpg"
or     ext == ".JPG" then
	dofile(__exec_dir__.."script/streamdef/jpg.lua")
	
elseif ext == ".ts"
or     ext == ".tts"
or     ext == ".m2ts"
or     ext == ".MPG"
or     ext == ".mpg" then
	dofile(__exec_dir__.."script/streamdef/ts.lua")
	
elseif ext == ".pes" then
	dofile(__exec_dir__.."script/streamdef/pes.lua")

elseif ext == ".h264" then
	dofile(__exec_dir__.."script/streamdef/h264.lua")

elseif ext == ".h265" then
	dofile(__exec_dir__.."script/streamdef/h265.lua")

elseif ext == ".mp4" then
	dofile(__exec_dir__.."script/streamdef/mp4.lua")

elseif ext == ".dat" then
	dofile(__exec_dir__.."script/streamdef/dat.lua")
	
elseif string.match(argv[1], "^[0-9a-fA-F][0-9a-fA-F] ") ~= nil then
	dofile(__exec_dir__.."script/streamdef/string.lua")

elseif ext == ".txt" then
	dump(256)
	
else
	print("not found extension")
end

-- SQLトランザクション終了
sql_commit()

-- 解析コマンド起動
cmd()

