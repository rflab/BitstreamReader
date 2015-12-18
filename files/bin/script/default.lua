-- コンソール引数をチェック
assert(argv[0], "no file name in argv[0]")
assert(argv[1], "no file name in argv[1]")

-- 設定ファイルとライブラリのロード
dofile(__exec_dir__.."script/util/include.lua")
dofile(__exec_dir__.."script/util.lua")
dofile(__exec_dir__.."script/command.lua")
dofile(__exec_dir__.."script/config.lua")
dofile(__exec_dir__.."script/streamdef/stream_dispatcher.lua")

-- SQLトランザクション開始
sql_begin()

-- ガベージコレクタ自動実行の停止（速度のため）
collectgarbage("stop")
print("collectgarbage", collectgarbage("isrunning"))

-- ストリーム解析
local stream = open(__stream_path__, "rb")
dispatch_stream(stream)

-- SQLトランザクション終了
sql_commit()

-- 解析完了（結果表示、エラー情報クリア）
exec_cmd("info")
exec_cmd("export log.csv")
exec_cmd("xmlexport log.xml")
os.remove(__error_info_path__)

-- 完全なガベージコレクションサイクルを実行
print("collectgarbage[kB]:", hexstr(math.ceil(collectgarbage("count"))))
collectgarbage("collect")

-- 解析コマンド起動
cmd()

