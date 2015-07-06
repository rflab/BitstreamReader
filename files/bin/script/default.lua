assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")

-- ライブラリロード
dofile(__exec_dir__.."script/util/include.lua")
dofile(__exec_dir__.."script/streamdef/stream_dispatcher.lua")

-- グローバル変数
local ep, __, en, ee = split_file_name(argv[0])
local sp, sd, sn, se = split_file_name(argv[1])
global("__exec_path__",   ep) print(ep)
global("__exec_name__",   en) print(en)
global("__exec_ext__",    ee) print(ee)
global("__stream_path__", sp) print(sp)
global("__stream_dir__",  sd) print(sd)
global("__stream_name__", sn) print(sn)
global("__stream_ext__",  se) print(se)
global("__out_dir__",     sd.."out/")
global("__stream_type__")

-- 解析結果出力先ディレクトリ作成
if windows then
	os.execute("mkdir \""..__out_dir__.."\"")
else
	os.execute("mkdir -p \""..__out_dir__.."\"")
end

-- SQLトランザクション開始
sql_begin()

-- ストリーム解析
local stream = open(__stream_path__, "rb")
dispatch_stream(stream)

-- SQLトランザクション終了
sql_commit()

-- 解析コマンド起動
cmd()

