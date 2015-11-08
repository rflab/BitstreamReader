assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")

-- ライブラリロード
dofile(__exec_dir__.."script/util/include.lua")
dofile(__exec_dir__.."script/streamdef/stream_dispatcher.lua")
dofile(__exec_dir__.."script/config.lua")

-- SQLトランザクション開始
sql_begin()

-- ガベージコレクタストップ
--collectgarbage("stop")
print("collectgarbage", collectgarbage("isrunning"))

-- ストリーム解析
local stream = open(__stream_path__, "rb")
dispatch_stream(stream)

-- SQLトランザクション終了
sql_commit()

-- ガベージコレクタ
print("collectgarbage(kB):", collectgarbage("count"))
collectgarbage("collect")

-- 解析コマンド起動
exec_cmd("info")
exec_cmd("save log.csv")
run_cmd_mode()

