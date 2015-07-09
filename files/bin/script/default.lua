assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")

-- ライブラリロード
dofile(__exec_dir__.."script/util/include.lua")
dofile(__exec_dir__.."script/streamdef/stream_dispatcher.lua")

-- グローバル変数
local ep, __, en, ee = split_file_name(argv[0])
local sp, sd, sn, se = split_file_name(argv[1])
print(global("__exec_path__",   ep))
print(global("__exec_name__",   en))
print(global("__exec_ext__",    ee))
print(global("__stream_path__", sp))
print(global("__stream_dir__",  sd))
print(global("__stream_name__", sn))
print(global("__stream_ext__",  se))
print(global("__out_dir__",        "out/"))
print(global("__streamdef_dir__",  "script/streamdef/"))
print(global("__stream_type__"))

-- 解析結果出力先ディレクトリ作成
if windows then
	--os.execute("mkdir \""..__out_dir__.."\"")
	os.execute("mkdir \""..__out_dir__.."\"")
	--os.execute("mkdir \"out/\"")
else
	--os.execute("mkdir -p \""..__out_dir__.."\"")
	os.execute("mkdir -p \""..__exec_dir__.."/out".."\"")
end

-- SQLトランザクション開始
sql_begin_3nf()
--sql_begin()

-- ストリーム解析
local stream = open(__stream_path__, "rb")
dispatch_stream(stream)

-- SQLトランザクション終了
sql_commit()

-- 解析コマンド起動
cmd()

