-- ライブラリロード
package.path = __exec_dir__.."script/module/?.lua"
require("profiler")
require("stream")
require("csv")

-- 関数はモジュール化しない
dofile(__exec_dir__.."script/module/util.lua")

