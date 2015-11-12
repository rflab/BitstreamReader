-- コンソール引数をチェック
assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")

-- ライブラリロード
dofile(__exec_dir__.."script/util/include.lua")
dofile(__exec_dir__.."script/streamdef/stream_dispatcher.lua")
dofile(__exec_dir__.."script/util.lua")
dofile(__exec_dir__.."script/command.lua")

-- 設定ファイルロード
dofile(__exec_dir__.."script/config.lua")

-- SQLトランザクション開始
sql_begin()

-- ガベージコレクタ自動実行の停止（速度のため）
collectgarbage("stop")
print("collectgarbage", collectgarbage("isrunning"))

-- ストリーム解析
local stream = open(__stream_path__, "rb")
enable_print(false)
dispatch_stream(stream)

-- SQLトランザクション終了
sql_commit()

-- 解析結果表示
exec_cmd("info")
exec_cmd("save log.csv")
os.remove(__error_info_path__)

-- 完全なガベージコレクションサイクルを実行
print("collectgarbage[kB]:", hexstr(math.ceil(collectgarbage("count"))))
collectgarbage("collect")

-- 解析コマンド起動
run_command_mode()

